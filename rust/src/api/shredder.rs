use rand::rngs::OsRng;
use rand::RngCore;
use std::fs::OpenOptions;
use std::io::{Seek, SeekFrom, Write};
use std::path::Path;

const CHUNK_SIZE: usize = 64 * 1024; // 64 KB chunk buffer

/// Pemusnahan fisik berkas dengan standar sanitasi DoD / NIST:
/// 1. Pass 1: Penimpaan byte acak CSPRNG (OsRng)
/// 2. Pass 2: Penimpaan byte nol (0x00)
/// 3. Sinkronisasi fisik chip memori (sync_all)
/// 4. Truncate ukuran file ke 0 byte
/// 5. Penghapusan file dari tabel alokasi (inode/FAT)
pub fn shred_file(path: String) -> Result<bool, String> {
    let p = Path::new(&path);
    if !p.exists() {
        return Ok(false);
    }

    if !p.is_file() {
        return Err(format!("Path bukan file biasa: {}", path));
    }

    let mut file = OpenOptions::new()
        .read(true)
        .write(true)
        .open(p)
        .map_err(|e| format!("Gagal membuka file untuk shredding: {}", e))?;

    let file_len = file
        .metadata()
        .map_err(|e| format!("Gagal membaca metadata file: {}", e))?
        .len();

    if file_len > 0 {
        let mut buffer = [0u8; CHUNK_SIZE];

        // Pass 1: Timpa seluruh sektor dengan byte acak kriptografis (OsRng)
        file.seek(SeekFrom::Start(0))
            .map_err(|e| format!("Gagal seek file (Pass 1): {}", e))?;

        let mut bytes_written = 0u64;
        while bytes_written < file_len {
            let to_write = std::cmp::min(CHUNK_SIZE as u64, file_len - bytes_written) as usize;
            OsRng.fill_bytes(&mut buffer[..to_write]);
            file.write_all(&buffer[..to_write])
                .map_err(|e| format!("Gagal menimpa byte acak: {}", e))?;
            bytes_written += to_write as u64;
        }
        file.sync_all()
            .map_err(|e| format!("Gagal sync hardware (Pass 1): {}", e))?;

        // Pass 2: Timpa seluruh sektor dengan byte 0x00 (Zero-filling)
        file.seek(SeekFrom::Start(0))
            .map_err(|e| format!("Gagal seek file (Pass 2): {}", e))?;

        buffer.fill(0x00);
        bytes_written = 0u64;
        while bytes_written < file_len {
            let to_write = std::cmp::min(CHUNK_SIZE as u64, file_len - bytes_written) as usize;
            file.write_all(&buffer[..to_write])
                .map_err(|e| format!("Gagal zero-filling: {}", e))?;
            bytes_written += to_write as u64;
        }
        file.sync_all()
            .map_err(|e| format!("Gagal sync hardware (Pass 2): {}", e))?;

        // Pass 3: Truncate panjang file ke 0 byte sebelum delete
        file.set_len(0)
            .map_err(|e| format!("Gagal truncate ukuran file: {}", e))?;
        file.sync_all()
            .map_err(|e| format!("Gagal sync truncate hardware: {}", e))?;
    }

    // Lepas file handle sebelum unlink dari filesystem
    drop(file);

    // Pass 4: Hapus dari tabel direktori / inode
    std::fs::remove_file(p).map_err(|e| format!("Gagal menghapus file dari filesystem: {}", e))?;

    Ok(true)
}

/// Memusnahkan seluruh berkas di dalam direktori secara rekursif (misalnya cache temporary audio/media)
pub fn shred_directory_contents(dir_path: String) -> Result<u32, String> {
    let dir = Path::new(&dir_path);
    if !dir.exists() || !dir.is_dir() {
        return Ok(0);
    }

    let mut shredded_count = 0u32;
    for entry in std::fs::read_dir(dir).map_err(|e| format!("Gagal membaca direktori: {}", e))? {
        let entry = entry.map_err(|e| format!("Gagal membaca entry: {}", e))?;
        let path = entry.path();
        if path.is_file() {
            if let Ok(true) = shred_file(path.to_string_lossy().to_string()) {
                shredded_count += 1;
            }
        } else if path.is_dir() {
            shredded_count += shred_directory_contents(path.to_string_lossy().to_string())?;
            let _ = std::fs::remove_dir(path);
        }
    }

    Ok(shredded_count)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::File;

    #[test]
    fn test_shred_non_existent_file() {
        let res = shred_file("non_existent_file_xyz_123.bin".to_string());
        assert_eq!(res.unwrap(), false);
    }

    #[test]
    fn test_shred_empty_file() {
        let temp_dir = std::env::temp_dir();
        let test_file = temp_dir.join("test_shred_empty.bin");
        File::create(&test_file).unwrap();

        assert!(test_file.exists());
        let res = shred_file(test_file.to_string_lossy().to_string());
        assert_eq!(res.unwrap(), true);
        assert!(!test_file.exists());
    }

    #[test]
    fn test_shred_populated_file() {
        let temp_dir = std::env::temp_dir();
        let test_file = temp_dir.join("test_shred_secret_128k.bin");
        {
            let mut f = File::create(&test_file).unwrap();
            let secret_payload = vec![0x42u8; 128 * 1024]; // 128 KB
            f.write_all(&secret_payload).unwrap();
            f.sync_all().unwrap();
        }

        assert!(test_file.exists());
        assert_eq!(test_file.metadata().unwrap().len(), 128 * 1024);

        let res = shred_file(test_file.to_string_lossy().to_string());
        assert_eq!(res.unwrap(), true);
        assert!(!test_file.exists());
    }

    #[test]
    fn test_shred_directory_contents() {
        let temp_dir = std::env::temp_dir().join("test_shred_dir_001");
        let _ = std::fs::remove_dir_all(&temp_dir);
        std::fs::create_dir_all(&temp_dir).unwrap();

        let f1 = temp_dir.join("file1.tmp");
        let f2 = temp_dir.join("file2.tmp");
        File::create(&f1).unwrap().write_all(b"rahasia 1").unwrap();
        File::create(&f2).unwrap().write_all(b"rahasia 2").unwrap();

        let count = shred_directory_contents(temp_dir.to_string_lossy().to_string()).unwrap();
        assert_eq!(count, 2);
        assert!(!f1.exists());
        assert!(!f2.exists());

        let _ = std::fs::remove_dir_all(&temp_dir);
    }
}
