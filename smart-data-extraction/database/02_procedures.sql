---Ingestion
DELIMITER //

CREATE PROCEDURE sp_IngestNewSource(
    IN p_file_name VARCHAR(255),
    IN p_raw_content LONGTEXT,
    IN p_file_path VARCHAR(500),
    OUT p_source_id INT
)
BEGIN
    -- Chèn dữ liệu mới vào hàng chờ
    INSERT INTO data_sources (file_name, raw_content, file_path, status)
    VALUES (p_file_name, p_raw_content, p_file_path, 'pending');
    
    -- Trả về ID vừa tạo để tầng App biết mà theo dõi
    SET p_source_id = LAST_INSERT_ID();
END //

DELIMITER ;



--Processing & Storage


DELIMITER //

CREATE OR REPLACE PROCEDURE sp_ProcessExtraction(IN p_source_id INT)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_rule_id INT;
    DECLARE v_keyword VARCHAR(100);
    DECLARE v_raw_text LONGTEXT;
    
    DECLARE cur_rules CURSOR FOR SELECT id, search_pattern FROM extraction_rules WHERE is_active = 1;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    SELECT raw_content INTO v_raw_text FROM data_sources WHERE id = p_source_id;

    OPEN cur_rules;
    read_loop: LOOP
        FETCH cur_rules INTO v_rule_id, v_keyword;
        IF done THEN LEAVE read_loop; END IF;

        IF LOCATE(v_keyword, v_raw_text) > 0 THEN
            INSERT INTO extracted_values (source_id, rule_id, extracted_value, metadata)
            VALUES (p_source_id, v_rule_id, CONCAT('Found: ', v_keyword), JSON_OBJECT('at', NOW()));
        END IF;
    END LOOP;
    CLOSE cur_rules;
    
    -- KHÔNG UPDATE data_sources ở đây để tránh lỗi #1442
END //
DELIMITER ;



--Trigger --The Auto-Extractor

DELIMITER //

CREATE TRIGGER trg_After_Ingest_Process
AFTER INSERT ON data_sources
FOR EACH ROW
BEGIN
    -- Kiểm tra nếu nội dung không rỗng thì mới chạy xử lý
    IF NEW.raw_content IS NOT NULL AND NEW.raw_content <> '' THEN
        -- Gọi trực tiếp Procedure xử lý mà chúng ta đã tối ưu
        CALL sp_ProcessExtraction(NEW.id);
    END IF;
END //

DELIMITER ;


--Báo cáo Pivot Động (The Reporting Engine)

DELIMITER //

CREATE PROCEDURE sp_GeneratePivotReport()
BEGIN
    -- 1. Khai báo biến để chứa câu lệnh SQL động
    SET @sql = NULL;

    -- 2. Xây dựng các cột động dựa trên keyword_label trong bảng Rules
    SELECT
      GROUP_CONCAT(DISTINCT
        CONCAT(
          'MAX(IF(er.keyword_label = ''',
          keyword_label,
          ''', ev.extracted_value, NULL)) AS `',
          keyword_label,
          '`'
        )
      ) INTO @sql
    FROM extraction_rules;

    -- 3. Ghép nối thành câu Query hoàn chỉnh
    SET @sql = CONCAT('SELECT ds.file_name, ds.status, ', @sql, ' 
                      FROM data_sources ds
                      LEFT JOIN extracted_values ev ON ds.id = ev.source_id
                      LEFT JOIN extraction_rules er ON ev.rule_id = er.id
                      GROUP BY ds.id');

    -- 4. Thực thi câu lệnh SQL vừa tạo
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //

DELIMITER ;
---nang gioi han chuoi GROUP_CONCAT neu KEYWORD(RULES) qua dai:
SET SESSION group_concat_max_len = 10000;
