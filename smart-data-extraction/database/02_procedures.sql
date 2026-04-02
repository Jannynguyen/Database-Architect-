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
