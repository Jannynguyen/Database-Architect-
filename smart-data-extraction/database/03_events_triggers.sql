

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

