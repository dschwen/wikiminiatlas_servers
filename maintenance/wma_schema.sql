-- MySQL dump 10.13  Distrib 5.5.12, for solaris10 (i386)
--
-- Host: sql-s1-user.toolserver.org    Database: u_dschwen
-- ------------------------------------------------------
-- Server version	5.1.59

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES latin1 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `wma_connect`
--

DROP TABLE IF EXISTS `wma_connect`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `wma_connect` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tile_id` int(11) DEFAULT NULL,
  `label_id` int(11) DEFAULT NULL,
  `rev` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `tile_id_index` (`tile_id`)
) ENGINE=InnoDB AUTO_INCREMENT=39435825 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `wma_label`
--

DROP TABLE IF EXISTS `wma_label`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `wma_label` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `page_id` int(11) DEFAULT NULL,
  `lang_id` int(11) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `style` int(11) DEFAULT NULL,
  `lat` double(11,8) DEFAULT NULL,
  `lon` double(11,8) DEFAULT NULL,
  `weight` int(11) DEFAULT NULL,
  `globe` enum('','Mercury','Ariel','Phobos','Deimos','Mars','Rhea','Oberon','Europa','Tethys','Pluto','Miranda','Titania','Phoebe','Enceladus','Venus','Moon','Hyperion','Triton','Ceres','Dione','Titan','Ganymede','Umbriel','Callisto','Jupiter','Io','Earth','Mimas','Iapetus') DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10974483 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `wma_tile`
--

DROP TABLE IF EXISTS `wma_tile`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `wma_tile` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `x` int(11) NOT NULL,
  `y` int(11) NOT NULL,
  `z` tinyint(4) NOT NULL DEFAULT '14',
  `xh` int(11) NOT NULL,
  `yh` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `z_index` (`z`),
  KEY `zxy_index` (`z`,`x`,`y`),
  KEY `zxhyh_index` (`z`,`xh`,`yh`)
) ENGINE=InnoDB AUTO_INCREMENT=4068689 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2012-08-13  2:15:48
