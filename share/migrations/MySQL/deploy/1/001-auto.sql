-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Wed Jun 10 12:05:26 2015
-- 
;
SET foreign_key_checks=0;
--
-- Table: `alert`
--
CREATE TABLE `alert` (
  `id` integer NOT NULL auto_increment,
  `view_id` integer NOT NULL,
  `user_id` integer NOT NULL,
  `frequency` integer NOT NULL DEFAULT 0,
  INDEX `alert_idx_user_id` (`user_id`),
  INDEX `alert_idx_view_id` (`view_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `alert_fk_user_id` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `alert_fk_view_id` FOREIGN KEY (`view_id`) REFERENCES `view` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `alert_cache`
--
CREATE TABLE `alert_cache` (
  `id` integer NOT NULL auto_increment,
  `layout_id` integer NOT NULL,
  `view_id` integer NOT NULL,
  `current_id` integer NOT NULL,
  INDEX `alert_cache_idx_current_id` (`current_id`),
  INDEX `alert_cache_idx_layout_id` (`layout_id`),
  INDEX `alert_cache_idx_view_id` (`view_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `alert_cache_fk_current_id` FOREIGN KEY (`current_id`) REFERENCES `current` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `alert_cache_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `alert_cache_fk_view_id` FOREIGN KEY (`view_id`) REFERENCES `view` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `alert_send`
--
CREATE TABLE `alert_send` (
  `id` integer NOT NULL auto_increment,
  `layout_id` integer NULL,
  `alert_id` integer NOT NULL,
  `current_id` integer NOT NULL,
  `status` char(7) NULL,
  INDEX `alert_send_idx_alert_id` (`alert_id`),
  INDEX `alert_send_idx_current_id` (`current_id`),
  INDEX `alert_send_idx_layout_id` (`layout_id`),
  PRIMARY KEY (`id`),
  UNIQUE `alert_send_all` (`layout_id`, `alert_id`, `current_id`, `status`),
  CONSTRAINT `alert_send_fk_alert_id` FOREIGN KEY (`alert_id`) REFERENCES `alert` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `alert_send_fk_current_id` FOREIGN KEY (`current_id`) REFERENCES `current` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `alert_send_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `audit`
--
CREATE TABLE `audit` (
  `id` integer NOT NULL auto_increment,
  `user_id` integer NULL,
  `description` text NULL,
  `type` varchar(45) NULL,
  `datetime` datetime NULL,
  INDEX `audit_idx_user_id` (`user_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `audit_fk_user_id` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `calc`
--
CREATE TABLE `calc` (
  `id` integer NOT NULL auto_increment,
  `layout_id` integer NULL,
  `calc` mediumtext NULL,
  `return_format` varchar(45) NULL,
  INDEX `calc_idx_layout_id` (`layout_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `calc_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `calcval`
--
CREATE TABLE `calcval` (
  `id` integer NOT NULL auto_increment,
  `record_id` integer NOT NULL,
  `layout_id` integer NOT NULL,
  `value` text NULL,
  INDEX `calcval_idx_layout_id` (`layout_id`),
  INDEX `calcval_idx_record_id` (`record_id`),
  PRIMARY KEY (`id`),
  UNIQUE `index4` (`record_id`, `layout_id`),
  CONSTRAINT `calcval_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `calcval_fk_record_id` FOREIGN KEY (`record_id`) REFERENCES `record` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `current`
--
CREATE TABLE `current` (
  `id` integer NOT NULL auto_increment,
  `serial` varchar(45) NULL,
  `record_id` integer NULL,
  `instance_id` integer NULL,
  INDEX `current_idx_instance_id` (`instance_id`),
  INDEX `current_idx_record_id` (`record_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `current_fk_instance_id` FOREIGN KEY (`instance_id`) REFERENCES `instance` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `current_fk_record_id` FOREIGN KEY (`record_id`) REFERENCES `record` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `date`
--
CREATE TABLE `date` (
  `id` integer NOT NULL auto_increment,
  `record_id` integer NOT NULL,
  `layout_id` integer NOT NULL,
  `value` date NULL,
  INDEX `date_idx_layout_id` (`layout_id`),
  INDEX `date_idx_record_id` (`record_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `date_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `date_fk_record_id` FOREIGN KEY (`record_id`) REFERENCES `record` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `daterange`
--
CREATE TABLE `daterange` (
  `id` integer NOT NULL auto_increment,
  `record_id` integer NOT NULL,
  `layout_id` integer NOT NULL,
  `from` date NULL,
  `to` date NULL,
  `value` varchar(45) NULL,
  INDEX `daterange_idx_layout_id` (`layout_id`),
  INDEX `daterange_idx_record_id` (`record_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `daterange_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `daterange_fk_record_id` FOREIGN KEY (`record_id`) REFERENCES `record` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `enum`
--
CREATE TABLE `enum` (
  `id` integer NOT NULL auto_increment,
  `record_id` integer NULL,
  `layout_id` integer NULL,
  `value` integer NULL,
  INDEX `enum_idx_layout_id` (`layout_id`),
  INDEX `enum_idx_record_id` (`record_id`),
  INDEX `enum_idx_value` (`value`),
  PRIMARY KEY (`id`),
  CONSTRAINT `enum_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `enum_fk_record_id` FOREIGN KEY (`record_id`) REFERENCES `record` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `enum_fk_value` FOREIGN KEY (`value`) REFERENCES `enumval` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `enumval`
--
CREATE TABLE `enumval` (
  `id` integer NOT NULL auto_increment,
  `enum_id` integer NULL,
  `value` text NULL,
  `layout_id` integer NULL,
  `deleted` smallint NOT NULL DEFAULT 0,
  `parent` integer NULL,
  INDEX `enumval_idx_layout_id` (`layout_id`),
  INDEX `enumval_idx_parent` (`parent`),
  PRIMARY KEY (`id`),
  CONSTRAINT `enumval_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `enumval_fk_parent` FOREIGN KEY (`parent`) REFERENCES `enumval` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `file`
--
CREATE TABLE `file` (
  `id` integer NOT NULL auto_increment,
  `record_id` integer NULL,
  `layout_id` integer NULL,
  `value` integer NULL,
  INDEX `file_idx_layout_id` (`layout_id`),
  INDEX `file_idx_record_id` (`record_id`),
  INDEX `file_idx_value` (`value`),
  PRIMARY KEY (`id`),
  CONSTRAINT `file_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `file_fk_record_id` FOREIGN KEY (`record_id`) REFERENCES `record` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `file_fk_value` FOREIGN KEY (`value`) REFERENCES `fileval` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `file_option`
--
CREATE TABLE `file_option` (
  `id` integer NOT NULL auto_increment,
  `layout_id` integer NOT NULL,
  `filesize` integer NULL,
  INDEX `file_option_idx_layout_id` (`layout_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `file_option_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `fileval`
--
CREATE TABLE `fileval` (
  `id` integer NOT NULL auto_increment,
  `name` text NULL,
  `mimetype` varchar(45) NULL,
  `content` longblob NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `filter`
--
CREATE TABLE `filter` (
  `id` integer NOT NULL auto_increment,
  `view_id` integer NOT NULL,
  `layout_id` integer NOT NULL,
  INDEX `filter_idx_layout_id` (`layout_id`),
  INDEX `filter_idx_view_id` (`view_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `filter_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `filter_fk_view_id` FOREIGN KEY (`view_id`) REFERENCES `view` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `graph`
--
CREATE TABLE `graph` (
  `id` integer NOT NULL auto_increment,
  `title` text NULL,
  `description` text NULL,
  `y_axis` integer NULL,
  `y_axis_stack` varchar(45) NULL,
  `y_axis_label` varchar(128) NULL,
  `x_axis` integer NULL,
  `x_axis_grouping` varchar(45) NULL,
  `group_by` integer NULL,
  `stackseries` smallint NOT NULL DEFAULT 0,
  `type` varchar(45) NULL,
  `metric_group` integer NULL,
  INDEX `graph_idx_group_by` (`group_by`),
  INDEX `graph_idx_metric_group` (`metric_group`),
  INDEX `graph_idx_x_axis` (`x_axis`),
  INDEX `graph_idx_y_axis` (`y_axis`),
  PRIMARY KEY (`id`),
  CONSTRAINT `graph_fk_group_by` FOREIGN KEY (`group_by`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `graph_fk_metric_group` FOREIGN KEY (`metric_group`) REFERENCES `metric_group` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `graph_fk_x_axis` FOREIGN KEY (`x_axis`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `graph_fk_y_axis` FOREIGN KEY (`y_axis`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `group`
--
CREATE TABLE `group` (
  `id` integer NOT NULL auto_increment,
  `name` varchar(128) NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `instance`
--
CREATE TABLE `instance` (
  `id` integer NOT NULL auto_increment,
  `name` varchar(45) NULL,
  `email_welcome_text` text NULL,
  `email_welcome_subject` varchar(128) NULL,
  `email_delete_text` text NULL,
  `email_delete_subject` varchar(128) NULL,
  `email_reject_text` text NULL,
  `email_reject_subject` varchar(128) NULL,
  `register_text` text NULL,
  `sort_layout_id` integer NULL,
  `sort_type` varchar(45) NULL,
  `homepage_text` text NULL,
  `homepage_text2` text NULL,
  `register_title_help` text NULL,
  `register_telephone_help` text NULL,
  `register_email_help` text NULL,
  `register_organisation_help` text NULL,
  `register_notes_help` text NULL,
  INDEX `instance_idx_sort_layout_id` (`sort_layout_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `instance_fk_sort_layout_id` FOREIGN KEY (`sort_layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `intgr`
--
CREATE TABLE `intgr` (
  `id` integer NOT NULL auto_increment,
  `record_id` integer NOT NULL,
  `layout_id` integer NOT NULL,
  `value` integer NULL,
  INDEX `intgr_idx_layout_id` (`layout_id`),
  INDEX `intgr_idx_record_id` (`record_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `intgr_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `intgr_fk_record_id` FOREIGN KEY (`record_id`) REFERENCES `record` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `layout`
--
CREATE TABLE `layout` (
  `id` integer NOT NULL auto_increment,
  `name` varchar(45) NULL,
  `type` varchar(45) NULL,
  `permission` integer NOT NULL DEFAULT 0,
  `optional` smallint NOT NULL DEFAULT 0,
  `remember` smallint NOT NULL DEFAULT 0,
  `position` integer NULL,
  `ordering` varchar(45) NULL,
  `end_node_only` smallint NOT NULL DEFAULT 0,
  `description` text NULL,
  `helptext` text NULL,
  `display_field` integer NULL,
  `display_regex` text NULL,
  `hidden` smallint NOT NULL DEFAULT 0,
  INDEX `layout_idx_display_field` (`display_field`),
  PRIMARY KEY (`id`),
  CONSTRAINT `layout_fk_display_field` FOREIGN KEY (`display_field`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `layout_depend`
--
CREATE TABLE `layout_depend` (
  `id` integer NOT NULL auto_increment,
  `layout_id` integer NOT NULL,
  `depends_on` integer NOT NULL,
  INDEX `layout_depend_idx_depends_on` (`depends_on`),
  INDEX `layout_depend_idx_layout_id` (`layout_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `layout_depend_fk_depends_on` FOREIGN KEY (`depends_on`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `layout_depend_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `layout_group`
--
CREATE TABLE `layout_group` (
  `id` integer NOT NULL auto_increment,
  `layout_id` integer NOT NULL,
  `group_id` integer NOT NULL,
  `permission` varchar(45) NOT NULL,
  INDEX `layout_group_idx_group_id` (`group_id`),
  INDEX `layout_group_idx_layout_id` (`layout_id`),
  PRIMARY KEY (`id`),
  UNIQUE `index4` (`layout_id`, `group_id`, `permission`),
  CONSTRAINT `layout_group_fk_group_id` FOREIGN KEY (`group_id`) REFERENCES `group` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `layout_group_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `metric`
--
CREATE TABLE `metric` (
  `id` integer NOT NULL auto_increment,
  `metric_group` integer NOT NULL,
  `x_axis_value` text NULL,
  `target` integer NULL,
  `y_axis_grouping_value` text NULL,
  INDEX `metric_idx_metric_group` (`metric_group`),
  PRIMARY KEY (`id`),
  CONSTRAINT `metric_fk_metric_group` FOREIGN KEY (`metric_group`) REFERENCES `metric_group` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `metric_group`
--
CREATE TABLE `metric_group` (
  `id` integer NOT NULL auto_increment,
  `name` text NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `organisation`
--
CREATE TABLE `organisation` (
  `id` integer NOT NULL auto_increment,
  `name` varchar(128) NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `permission`
--
CREATE TABLE `permission` (
  `id` integer NOT NULL auto_increment,
  `name` varchar(128) NOT NULL,
  `description` text NULL,
  `order` integer NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `person`
--
CREATE TABLE `person` (
  `id` integer NOT NULL auto_increment,
  `record_id` integer NULL,
  `layout_id` integer NULL,
  `value` integer NULL,
  INDEX `person_idx_layout_id` (`layout_id`),
  INDEX `person_idx_record_id` (`record_id`),
  INDEX `person_idx_value` (`value`),
  PRIMARY KEY (`id`),
  CONSTRAINT `person_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `person_fk_record_id` FOREIGN KEY (`record_id`) REFERENCES `record` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `person_fk_value` FOREIGN KEY (`value`) REFERENCES `user` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `rag`
--
CREATE TABLE `rag` (
  `id` integer NOT NULL auto_increment,
  `layout_id` integer NOT NULL,
  `red` text NULL,
  `amber` text NULL,
  `green` text NULL,
  INDEX `rag_idx_layout_id` (`layout_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `rag_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `ragval`
--
CREATE TABLE `ragval` (
  `id` integer NOT NULL auto_increment,
  `record_id` integer NOT NULL,
  `layout_id` integer NOT NULL,
  `value` text NULL,
  INDEX `ragval_idx_layout_id` (`layout_id`),
  INDEX `ragval_idx_record_id` (`record_id`),
  PRIMARY KEY (`id`),
  UNIQUE `index4` (`record_id`, `layout_id`),
  CONSTRAINT `ragval_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `ragval_fk_record_id` FOREIGN KEY (`record_id`) REFERENCES `record` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `record`
--
CREATE TABLE `record` (
  `id` integer NOT NULL auto_increment,
  `created` datetime NOT NULL,
  `current_id` integer NOT NULL DEFAULT 0,
  `createdby` integer NULL,
  `approvedby` integer NULL,
  `record_id` integer NULL,
  `approval` smallint NOT NULL DEFAULT 0,
  INDEX `record_idx_approvedby` (`approvedby`),
  INDEX `record_idx_createdby` (`createdby`),
  INDEX `record_idx_current_id` (`current_id`),
  INDEX `record_idx_record_id` (`record_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `record_fk_approvedby` FOREIGN KEY (`approvedby`) REFERENCES `user` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `record_fk_createdby` FOREIGN KEY (`createdby`) REFERENCES `user` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `record_fk_current_id` FOREIGN KEY (`current_id`) REFERENCES `current` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `record_fk_record_id` FOREIGN KEY (`record_id`) REFERENCES `record` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `sort`
--
CREATE TABLE `sort` (
  `id` integer NOT NULL auto_increment,
  `view_id` integer NOT NULL,
  `layout_id` integer NULL,
  `type` varchar(45) NULL,
  INDEX `sort_idx_layout_id` (`layout_id`),
  INDEX `sort_idx_view_id` (`view_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `sort_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `sort_fk_view_id` FOREIGN KEY (`view_id`) REFERENCES `view` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `string`
--
CREATE TABLE `string` (
  `id` integer NOT NULL auto_increment,
  `record_id` integer NOT NULL,
  `layout_id` integer NOT NULL,
  `value` text NULL,
  INDEX `string_idx_layout_id` (`layout_id`),
  INDEX `string_idx_record_id` (`record_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `string_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `string_fk_record_id` FOREIGN KEY (`record_id`) REFERENCES `record` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `title`
--
CREATE TABLE `title` (
  `id` integer NOT NULL auto_increment,
  `name` varchar(128) NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `user`
--
CREATE TABLE `user` (
  `id` integer NOT NULL auto_increment,
  `firstname` varchar(45) NULL,
  `surname` varchar(45) NULL,
  `email` varchar(45) NULL,
  `username` varchar(45) NULL,
  `title` integer NULL,
  `organisation` integer NULL,
  `telephone` varchar(128) NULL,
  `permission` smallint NOT NULL DEFAULT 0,
  `password` varchar(128) NULL,
  `pwchanged` datetime NULL,
  `resetpw` varchar(32) NULL,
  `deleted` smallint NOT NULL DEFAULT 0,
  `lastlogin` datetime NULL,
  `lastrecord` integer NULL,
  `lastview` integer NULL,
  `value` text NULL,
  `account_request` smallint NULL DEFAULT 0,
  `account_request_notes` text NULL,
  `aup_accepted` datetime NULL,
  INDEX `user_idx_lastrecord` (`lastrecord`),
  INDEX `user_idx_lastview` (`lastview`),
  INDEX `user_idx_organisation` (`organisation`),
  INDEX `user_idx_title` (`title`),
  PRIMARY KEY (`id`),
  CONSTRAINT `user_fk_lastrecord` FOREIGN KEY (`lastrecord`) REFERENCES `record` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `user_fk_lastview` FOREIGN KEY (`lastview`) REFERENCES `view` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `user_fk_organisation` FOREIGN KEY (`organisation`) REFERENCES `organisation` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `user_fk_title` FOREIGN KEY (`title`) REFERENCES `title` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `user_graph`
--
CREATE TABLE `user_graph` (
  `id` integer NOT NULL auto_increment,
  `user_id` integer NOT NULL,
  `graph_id` integer NOT NULL,
  INDEX `user_graph_idx_graph_id` (`graph_id`),
  INDEX `user_graph_idx_user_id` (`user_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `user_graph_fk_graph_id` FOREIGN KEY (`graph_id`) REFERENCES `graph` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `user_graph_fk_user_id` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `user_group`
--
CREATE TABLE `user_group` (
  `id` integer NOT NULL auto_increment,
  `user_id` integer NOT NULL,
  `group_id` integer NOT NULL,
  INDEX `user_group_idx_group_id` (`group_id`),
  INDEX `user_group_idx_user_id` (`user_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `user_group_fk_group_id` FOREIGN KEY (`group_id`) REFERENCES `group` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `user_group_fk_user_id` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `user_permission`
--
CREATE TABLE `user_permission` (
  `id` integer NOT NULL auto_increment,
  `user_id` integer NOT NULL,
  `permission_id` integer NOT NULL,
  INDEX `user_permission_idx_permission_id` (`permission_id`),
  INDEX `user_permission_idx_user_id` (`user_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `user_permission_fk_permission_id` FOREIGN KEY (`permission_id`) REFERENCES `permission` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `user_permission_fk_user_id` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `view`
--
CREATE TABLE `view` (
  `id` integer NOT NULL auto_increment,
  `user_id` integer NULL,
  `name` varchar(128) NULL,
  `global` smallint NOT NULL DEFAULT 0,
  `filter` text NULL,
  INDEX `view_idx_user_id` (`user_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `view_fk_user_id` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `view_layout`
--
CREATE TABLE `view_layout` (
  `id` integer NOT NULL auto_increment,
  `view_id` integer NOT NULL,
  `layout_id` integer NOT NULL,
  `order` integer NULL,
  INDEX `view_layout_idx_layout_id` (`layout_id`),
  INDEX `view_layout_idx_view_id` (`view_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `view_layout_fk_layout_id` FOREIGN KEY (`layout_id`) REFERENCES `layout` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `view_layout_fk_view_id` FOREIGN KEY (`view_id`) REFERENCES `view` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
SET foreign_key_checks=1;
