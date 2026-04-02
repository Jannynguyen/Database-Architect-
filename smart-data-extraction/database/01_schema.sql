
-- 1. Create table for raw data (files and texts)
CREATE TABLE `data_sources` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `file_name` VARCHAR(255),
  `raw_content` LONGTEXT, -- Lưu nội dung văn bản sau khi trích xuất từ file
  `file_path` VARCHAR(500),
  `status` ENUM('pending', 'processed', 'error') DEFAULT 'pending',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. User-defined Keywords table
CREATE TABLE `extraction_rules` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `keyword_label` VARCHAR(100), -- Ví dụ: "Số hóa đơn", "Ngày hết hạn"
  `search_pattern` VARCHAR(255), -- Từ khóa hoặc Regex để máy tìm trong văn bản
  `is_active` TINYINT(1) DEFAULT 1
) ENGINE=InnoDB;

-- 3. Extracted data table 
-- JSON for save data MySQL/MariaDB của XAMPP
CREATE TABLE `extracted_values` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `source_id` INT,
  `rule_id` INT,
  `extracted_value` TEXT,
  `metadata` JSON, -- add  more primary datas
  FOREIGN KEY (`source_id`) REFERENCES `data_sources`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`rule_id`) REFERENCES `extraction_rules`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

ALTER TABLE data_sources ADD FULLTEXT(raw_content);
