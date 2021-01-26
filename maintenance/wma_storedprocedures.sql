DROP PROCEDURE IF EXISTS InsertLabel_${lang};
DELIMITER //
CREATE PROCEDURE InsertLabel_${lang}( IN ppageid INT(11), IN pname VARCHAR(255), IN pstyle INT(11),
                              IN pglobe SMALLINT,
                              IN plat FLOAT, IN plon FLOAT, IN pweight INT(11), IN ptileid INT(11), IN prev INT(11) )
  BEGIN
    INSERT INTO wma_label_${lang} (page_id,name,style,lat,lon,weight,globe) VALUES ( ppageid, pname, pstyle, plat, plon, pweight, pglobe );
    INSERT INTO wma_connect_${lang} (tile_id,label_id,rev) VALUES ( ptileid, LAST_INSERT_ID(), prev );
  END //
DELIMITER ;
