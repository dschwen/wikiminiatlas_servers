ALTER TABLE wma_tile DROP INDEX id_index;
ALTER TABLE wma_tile DROP INDEX x_index;
ALTER TABLE wma_tile DROP INDEX y_index;
ALTER TABLE wma_tile DROP INDEX xh_index;
ALTER TABLE wma_tile DROP INDEX yh_index;
ALTER TABLE wma_tile DROP COLUMN rev;
ALTER TABLE  `wma_tile` CHANGE  `x`  `x` INT( 11 ) NOT NULL;
ALTER TABLE  `wma_tile` CHANGE  `y`  `y` INT( 11 ) NOT NULL;
ALTER TABLE  `wma_tile` CHANGE  `xh`  `xh` INT( 11 ) NOT NULL;
ALTER TABLE  `wma_tile` CHANGE  `yh`  `yh` INT( 11 ) NOT NULL;
ALTER TABLE wma_tile CHANGE z z TINYINT(4) NOT NULL DEFAULT '14';
CREATE INDEX `zxy_index` ON wma_tile (`z`,`x`,`y`);
CREATE INDEX `zxhyh_index` ON wma_tile (`z`,`xh`,`yh`);

