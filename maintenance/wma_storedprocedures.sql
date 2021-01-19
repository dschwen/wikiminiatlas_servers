DROP PROCEDURE IF EXISTS InsertLabel;
DELIMITER //
CREATE PROCEDURE InsertLabel( IN ppageid INT(11), IN plangid INT(11), IN pname VARCHAR(255), IN pstyle INT(11),
                              IN pglobe SMALLINT,
                              IN plat FLOAT, IN plon FLOAT, IN pweight INT(11), IN ptileid INT(11), IN prev INT(11) )
  BEGIN
    INSERT INTO wma_label (page_id,lang_id,name,style,lat,lon,weight,globe) VALUES ( ppageid, plangid, pname, pstyle, plat, plon, pweight, pglobe );
    INSERT INTO wma_connect (tile_id,label_id,rev) VALUES ( ptileid, LAST_INSERT_ID(), prev );
  END //
DELIMITER ;
