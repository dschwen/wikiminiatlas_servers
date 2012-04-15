DROP PROCEDURE IF EXISTS InsertLabel;
DELIMITER //
CREATE PROCEDURE InsertLabel( IN ppageid INT(11), IN plangid INT(11), IN pname VARCHAR(255), IN pstyle INT(11), 
                              IN pglobe ENUM('','Mercury','Ariel','Phobos','Deimos','Mars','Rhea','Oberon','Europa','Tethys','Pluto','Miranda','Titania','Phoebe','Enceladus','Venus','Moon','Hyperion','Triton','Ceres','Dione','Titan','Ganymede','Umbriel','Callisto','Jupiter','Io','Earth','Mimas','Iapetus'),
                              IN plat FLOAT, IN plon FLOAT, IN pweight INT(11), IN ptileid INT(11), IN prev INT(11) )
  BEGIN
    INSERT INTO wma_label (page_id,lang_id,name,style,lat,lon,weight,globe) VALUES ( ppageid, plangid, pname, pstyle, plat, plon, pweight, pglobe );
    INSERT INTO wma_connect (tile_id,label_id,rev) VALUES ( ptileid, LAST_INSERT_ID(), prev );
  END //
DELIMITER ;
