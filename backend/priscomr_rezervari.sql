-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: db:3306
-- Generation Time: Oct 22, 2025 at 08:20 AM
-- Server version: 10.11.13-MariaDB-ubu2204
-- PHP Version: 8.3.26

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `priscomr_rezervari`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`priscomr_rezervariuser`@`%` PROCEDURE `sp_fill_trip_stations` (IN `p_trip_id` INT)   BEGIN
  DECLARE v_route_id INT;

  SELECT route_id INTO v_route_id
  FROM trips
  WHERE id = p_trip_id
  LIMIT 1;

  -- ștergem eventuale rânduri existente (reluări / regenerări controlate)
  DELETE FROM trip_stations WHERE trip_id = p_trip_id;

  -- copiem ordinea stațiilor din route_stations (snapshot)
  INSERT INTO trip_stations (trip_id, station_id, sequence)
  SELECT p_trip_id, rs.station_id, rs.sequence
  FROM route_stations rs
  WHERE rs.route_id = v_route_id
  ORDER BY rs.sequence;
END$$

CREATE DEFINER=`priscomr_rezervariuser`@`%` PROCEDURE `sp_free_seats` (IN `p_trip_id` INT, IN `p_board_station_id` INT, IN `p_exit_station_id` INT)   BEGIN
  DECLARE v_bseq INT;
  DECLARE v_eseq INT;

  -- Luăm secvențele stațiilor selectate (urcare și coborâre)
  SELECT sequence INTO v_bseq 
  FROM trip_stations 
  WHERE trip_id = p_trip_id AND station_id = p_board_station_id 
  LIMIT 1;

  SELECT sequence INTO v_eseq 
  FROM trip_stations 
  WHERE trip_id = p_trip_id AND station_id = p_exit_station_id 
  LIMIT 1;

  -- Dacă ceva nu e valid, returnăm tabel gol
  IF v_bseq IS NULL OR v_eseq IS NULL OR v_bseq >= v_eseq THEN
    SELECT NULL AS id, NULL AS label, NULL AS status WHERE 1=0;
  ELSE
    SELECT 
      s.id,
      s.label,
      s.row,
      s.seat_col,
      s.seat_type,
      s.pair_id,
      CASE
        WHEN COUNT(r.id) = 0 THEN 'free'
        WHEN SUM(
          NOT (
            ts_e.sequence <= v_bseq OR 
            ts_b.sequence >= v_eseq
          )
        ) > 0 AND 
          SUM(
            ts_b.sequence <= v_bseq AND ts_e.sequence >= v_eseq
          ) = 0
        THEN 'partial'
        ELSE 'full'
      END AS status
    FROM seats s
    JOIN trips t ON t.id = p_trip_id AND t.vehicle_id = s.vehicle_id
    LEFT JOIN reservations r 
      ON r.trip_id = p_trip_id 
      AND r.seat_id = s.id 
      AND r.status = 'active'
    LEFT JOIN trip_stations ts_b 
      ON ts_b.trip_id = r.trip_id 
      AND ts_b.station_id = r.board_station_id
    LEFT JOIN trip_stations ts_e 
      ON ts_e.trip_id = r.trip_id 
      AND ts_e.station_id = r.exit_station_id
    WHERE s.seat_type IN ('normal','foldable','wheelchair','driver','guide')
    GROUP BY s.id, s.label, s.row, s.seat_col, s.seat_type, s.pair_id
    ORDER BY s.row, s.seat_col;
  END IF;
END$$

CREATE DEFINER=`priscomr_rezervariuser`@`%` PROCEDURE `sp_is_seat_free` (IN `p_trip_id` INT, IN `p_seat_id` INT, IN `p_board_station_id` INT, IN `p_exit_station_id` INT)   BEGIN
  DECLARE v_bseq INT DEFAULT NULL;
  DECLARE v_eseq INT DEFAULT NULL;

  SELECT ts.sequence INTO v_bseq
  FROM trip_stations ts
  WHERE ts.trip_id = p_trip_id AND ts.station_id = p_board_station_id
  LIMIT 1;

  SELECT ts.sequence INTO v_eseq
  FROM trip_stations ts
  WHERE ts.trip_id = p_trip_id AND ts.station_id = p_exit_station_id
  LIMIT 1;

  IF v_bseq IS NULL OR v_eseq IS NULL OR v_bseq >= v_eseq THEN
    SELECT 0 AS is_free;
  ELSE
    SELECT CASE WHEN EXISTS (
      SELECT 1
      FROM reservations r
      JOIN trip_stations ts_b ON ts_b.trip_id = r.trip_id AND ts_b.station_id = r.board_station_id
      JOIN trip_stations ts_e ON ts_e.trip_id = r.trip_id AND ts_e.station_id = r.exit_station_id
      WHERE r.trip_id = p_trip_id
        AND r.seat_id = p_seat_id
        AND r.status = 'active'
        AND NOT (ts_e.sequence <= v_bseq OR ts_b.sequence >= v_eseq)
    ) THEN 0 ELSE 1 END AS is_free;
  END IF;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `agencies`
--

CREATE TABLE `agencies` (
  `id` int(11) NOT NULL,
  `name` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `agencies`
--

INSERT INTO `agencies` (`id`, `name`) VALUES(1, 'Agenția Botoșani');
INSERT INTO `agencies` (`id`, `name`) VALUES(2, 'Agenția Iași');
INSERT INTO `agencies` (`id`, `name`) VALUES(3, 'Agenția Hârlău');

-- --------------------------------------------------------

--
-- Table structure for table `audit_logs`
--

CREATE TABLE `audit_logs` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `actor_id` bigint(20) DEFAULT NULL,
  `entity` varchar(64) NOT NULL,
  `entity_id` bigint(20) DEFAULT NULL,
  `action` varchar(64) NOT NULL,
  `related_entity` varchar(64) DEFAULT 'reservation',
  `related_id` bigint(20) DEFAULT NULL,
  `correlation_id` char(36) DEFAULT NULL,
  `channel` enum('online','agent') DEFAULT NULL,
  `amount` decimal(10,2) DEFAULT NULL,
  `payment_method` enum('cash','card','online') DEFAULT NULL,
  `transaction_id` varchar(128) DEFAULT NULL,
  `note` varchar(255) DEFAULT NULL,
  `before_json` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`before_json`)),
  `after_json` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`after_json`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `audit_logs`
--

INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(22, '2025-10-21 14:06:22', 1, 'reservation', 84, 'reservation.create', 'reservation', NULL, 'e75de182-b174-4268-970a-b1f8b6a336f0', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(23, '2025-10-21 14:07:05', 1, 'reservation', 84, 'reservation.cancel', 'reservation', NULL, '8a9e54c6-6085-4811-b644-8447a936a2ff', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(24, '2025-10-21 14:07:05', 1, 'reservation', 85, 'reservation.create', 'reservation', 84, '8a9e54c6-6085-4811-b644-8447a936a2ff', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(25, '2025-10-21 14:07:05', 1, 'reservation', 85, 'reservation.move', 'reservation', 84, '8a9e54c6-6085-4811-b644-8447a936a2ff', 'agent', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(26, '2025-10-21 14:24:47', 1, 'reservation', 85, 'reservation.update', 'reservation', NULL, '485a66bc-7876-4047-99fd-7eee12e065a3', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(27, '2025-10-21 14:24:54', 1, 'reservation', 85, 'reservation.update', 'reservation', NULL, '79a85e99-4114-4132-afdc-0c4ccb99da57', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(28, '2025-10-21 14:30:50', 1, 'reservation', 85, 'reservation.update', 'reservation', NULL, 'e51ed4d3-1081-48f2-a040-81adfbfe5daf', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(29, '2025-10-21 14:31:38', 1, 'reservation', 85, 'reservation.update', 'reservation', NULL, 'be63db3c-03f6-48cb-a0d6-dc19cf7e289f', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(30, '2025-10-21 14:32:04', 1, 'reservation', 86, 'reservation.create', 'reservation', NULL, '3deb8208-8bbf-4980-9d1e-1a7c1387740b', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(31, '2025-10-21 14:32:11', 1, 'reservation', 86, 'reservation.update', 'reservation', NULL, 'd9e1358e-dc68-4fe1-9d2b-db23a430fc48', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(32, '2025-10-21 14:55:23', 1, 'reservation', 86, 'reservation.update', 'reservation', NULL, '0a4a10c3-2693-4a4c-9fc4-2f115b2a164c', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(33, '2025-10-21 16:10:57', 1, 'reservation', 87, 'reservation.create', 'reservation', NULL, '6189d9de-7d0b-460a-9fd8-d07171b0e7d7', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(34, '2025-10-21 22:11:12', 1, 'reservation', 88, 'reservation.create', 'reservation', NULL, 'e7792db0-b04e-4374-bfb2-7ae0a6ee1b75', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO `audit_logs` (`id`, `created_at`, `actor_id`, `entity`, `entity_id`, `action`, `related_entity`, `related_id`, `correlation_id`, `channel`, `amount`, `payment_method`, `transaction_id`, `note`, `before_json`, `after_json`) VALUES(35, '2025-10-22 11:10:15', 1, 'reservation', 89, 'reservation.create', 'reservation', NULL, '3e8507bb-6bdd-46a4-ab8a-2138f67f5e94', NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `blacklist`
--

CREATE TABLE `blacklist` (
  `id` int(11) NOT NULL,
  `person_id` int(11) DEFAULT NULL,
  `reason` text DEFAULT NULL,
  `added_by_employee_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cash_handovers`
--

CREATE TABLE `cash_handovers` (
  `id` int(11) NOT NULL,
  `employee_id` int(11) DEFAULT NULL,
  `operator_id` int(11) DEFAULT NULL,
  `amount` decimal(10,2) NOT NULL,
  `created_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `discount_types`
--

CREATE TABLE `discount_types` (
  `id` int(11) NOT NULL,
  `code` varchar(50) NOT NULL,
  `label` text NOT NULL,
  `value_off` decimal(5,2) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `type` enum('percent','fixed') NOT NULL DEFAULT 'percent'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `discount_types`
--

INSERT INTO `discount_types` (`id`, `code`, `label`, `value_off`, `created_at`, `type`) VALUES(1, 'pensionar', 'Pensionar - 50%', 50.00, '2025-07-28 15:25:12', 'percent');
INSERT INTO `discount_types` (`id`, `code`, `label`, `value_off`, `created_at`, `type`) VALUES(2, 'copil', 'Copil < 12 ani - 50%', 50.00, '2025-07-28 15:25:58', 'percent');
INSERT INTO `discount_types` (`id`, `code`, `label`, `value_off`, `created_at`, `type`) VALUES(3, 'das', 'DAS - 100%', 100.00, '2025-07-28 15:26:49', 'percent');
INSERT INTO `discount_types` (`id`, `code`, `label`, `value_off`, `created_at`, `type`) VALUES(4, 'vip', 'VIP', 100.00, '2025-07-28 19:30:39', 'percent');

-- --------------------------------------------------------

--
-- Table structure for table `employees`
--

CREATE TABLE `employees` (
  `id` int(11) NOT NULL,
  `name` text NOT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `password_hash` text DEFAULT NULL,
  `role` enum('driver','agent','operator_admin','admin') NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `operator_id` int(11) NOT NULL DEFAULT 1,
  `agency_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `employees`
--

INSERT INTO `employees` (`id`, `name`, `phone`, `email`, `password_hash`, `role`, `active`, `created_at`, `operator_id`, `agency_id`) VALUES(1, 'admin', '0743171315', NULL, '$2b$10$BTPemH/a0y0maTH7xnOrUObieWGcoQP/2/d3DQtpnehkAlsjqwkvG', 'admin', 1, '2025-08-04 13:46:37', 2, 1);
INSERT INTO `employees` (`id`, `name`, `phone`, `email`, `password_hash`, `role`, `active`, `created_at`, `operator_id`, `agency_id`) VALUES(2, 'test', NULL, NULL, NULL, 'driver', 1, '2025-08-21 10:53:13', 2, NULL);
INSERT INTO `employees` (`id`, `name`, `phone`, `email`, `password_hash`, `role`, `active`, `created_at`, `operator_id`, `agency_id`) VALUES(3, 'Ion Popescu', '0740123456', NULL, NULL, 'driver', 1, '2025-07-09 09:46:32', 1, NULL);
INSERT INTO `employees` (`id`, `name`, `phone`, `email`, `password_hash`, `role`, `active`, `created_at`, `operator_id`, `agency_id`) VALUES(4, 'Silion Vasile Razvan', NULL, NULL, NULL, 'driver', 1, '2025-07-09 14:15:50', 2, NULL);
INSERT INTO `employees` (`id`, `name`, `phone`, `email`, `password_hash`, `role`, `active`, `created_at`, `operator_id`, `agency_id`) VALUES(5, 'Roșu Iulian', NULL, 'rosuiulian@gmail.com', '$2b$10$BTPemH/a0y0maTH7xnOrUObieWGcoQP/2/d3DQtpnehkAlsjqwkvG', 'agent', 1, '2025-07-09 14:15:50', 2, 3);
INSERT INTO `employees` (`id`, `name`, `phone`, `email`, `password_hash`, `role`, `active`, `created_at`, `operator_id`, `agency_id`) VALUES(6, 'Petru Matei', NULL, NULL, NULL, 'driver', 1, '2025-07-09 14:15:50', 1, NULL);
INSERT INTO `employees` (`id`, `name`, `phone`, `email`, `password_hash`, `role`, `active`, `created_at`, `operator_id`, `agency_id`) VALUES(7, 'Guzic Bogdan Dumitru', NULL, NULL, NULL, 'driver', 1, '2025-07-09 14:15:50', 1, NULL);
INSERT INTO `employees` (`id`, `name`, `phone`, `email`, `password_hash`, `role`, `active`, `created_at`, `operator_id`, `agency_id`) VALUES(8, 'Daniel Calenciuc', NULL, NULL, NULL, 'agent', 1, '2025-08-21 10:49:42', 2, 2);
INSERT INTO `employees` (`id`, `name`, `phone`, `email`, `password_hash`, `role`, `active`, `created_at`, `operator_id`, `agency_id`) VALUES(9, 'Calenciuc Ema', '65465', NULL, NULL, 'agent', 1, '2025-08-21 10:52:26', 2, 3);

-- --------------------------------------------------------

--
-- Table structure for table `invitations`
--

CREATE TABLE `invitations` (
  `id` int(11) NOT NULL,
  `token` varchar(255) NOT NULL,
  `role` enum('driver','agent','operator_admin','admin') NOT NULL,
  `operator_id` int(11) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `expires_at` datetime NOT NULL,
  `created_by` int(11) DEFAULT NULL,
  `used_at` datetime DEFAULT NULL,
  `used_by` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `no_shows`
--

CREATE TABLE `no_shows` (
  `id` int(11) NOT NULL,
  `person_id` int(11) DEFAULT NULL,
  `trip_id` int(11) DEFAULT NULL,
  `seat_id` int(11) DEFAULT NULL,
  `reservation_id` int(11) DEFAULT NULL,
  `board_station_id` int(11) DEFAULT NULL,
  `exit_station_id` int(11) DEFAULT NULL,
  `added_by_employee_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `operators`
--

CREATE TABLE `operators` (
  `id` int(11) NOT NULL,
  `name` text NOT NULL,
  `pos_endpoint` text NOT NULL,
  `theme_color` varchar(7) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `operators`
--

INSERT INTO `operators` (`id`, `name`, `pos_endpoint`, `theme_color`) VALUES(1, 'Pris-Com', 'https://pos.priscom.ro/pay', '#FF0000');
INSERT INTO `operators` (`id`, `name`, `pos_endpoint`, `theme_color`) VALUES(2, 'Auto-Dimas', 'https://pos.autodimas.ro/pay', '#0000FF');

-- --------------------------------------------------------

--
-- Table structure for table `payments`
--

CREATE TABLE `payments` (
  `id` int(11) NOT NULL,
  `reservation_id` int(11) DEFAULT NULL,
  `amount` decimal(10,2) NOT NULL,
  `status` enum('pending','paid','failed') NOT NULL DEFAULT 'pending',
  `payment_method` varchar(20) DEFAULT NULL,
  `transaction_id` text DEFAULT NULL,
  `timestamp` datetime DEFAULT current_timestamp(),
  `deposited_at` date DEFAULT NULL,
  `deposited_by` int(11) DEFAULT NULL,
  `collected_by` int(11) DEFAULT NULL,
  `cash_handover_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `people`
--

CREATE TABLE `people` (
  `id` int(11) NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `owner_status` enum('active','pending','hidden') NOT NULL DEFAULT 'active',
  `prev_owner_id` int(11) DEFAULT NULL,
  `replaced_by_id` int(11) DEFAULT NULL,
  `owner_changed_by` int(11) DEFAULT NULL,
  `owner_changed_at` datetime DEFAULT NULL,
  `blacklist` tinyint(1) NOT NULL DEFAULT 0,
  `whitelist` tinyint(1) NOT NULL DEFAULT 0,
  `notes` text DEFAULT NULL,
  `notes_by` int(11) DEFAULT NULL,
  `notes_at` datetime DEFAULT NULL,
  `is_active` tinyint(1) GENERATED ALWAYS AS (case when `owner_status` = 'active' then 1 else NULL end) STORED,
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `people`
--

INSERT INTO `people` (`id`, `name`, `phone`, `owner_status`, `prev_owner_id`, `replaced_by_id`, `owner_changed_by`, `owner_changed_at`, `blacklist`, `whitelist`, `notes`, `notes_by`, `notes_at`, `updated_at`) VALUES(61, 'iulian', '1234567890', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-21 14:06:22');
INSERT INTO `people` (`id`, `name`, `phone`, `owner_status`, `prev_owner_id`, `replaced_by_id`, `owner_changed_by`, `owner_changed_at`, `blacklist`, `whitelist`, `notes`, `notes_by`, `notes_at`, `updated_at`) VALUES(62, 'bubulina', '5646865651648', 'active', NULL, NULL, NULL, NULL, 0, 0, '', NULL, NULL, '2025-10-21 14:33:08');

-- --------------------------------------------------------

--
-- Table structure for table `price_lists`
--

CREATE TABLE `price_lists` (
  `id` int(11) NOT NULL,
  `name` text NOT NULL,
  `version` int(11) NOT NULL DEFAULT 1,
  `effective_from` date NOT NULL,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `route_id` int(11) NOT NULL,
  `category_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `price_lists`
--

INSERT INTO `price_lists` (`id`, `name`, `version`, `effective_from`, `created_by`, `created_at`, `route_id`, `category_id`) VALUES(1, '1-1-2025-10-11', 1, '2025-10-11', 1, '2025-10-11 18:47:01', 1, 1);
INSERT INTO `price_lists` (`id`, `name`, `version`, `effective_from`, `created_by`, `created_at`, `route_id`, `category_id`) VALUES(2, '8-1-2025-10-11', 1, '2025-10-11', 1, '2025-10-11 19:50:15', 8, 1);
INSERT INTO `price_lists` (`id`, `name`, `version`, `effective_from`, `created_by`, `created_at`, `route_id`, `category_id`) VALUES(3, '1-1-2025-10-14', 1, '2025-10-14', 1, '2025-10-14 10:03:58', 1, 1);
INSERT INTO `price_lists` (`id`, `name`, `version`, `effective_from`, `created_by`, `created_at`, `route_id`, `category_id`) VALUES(4, '4-1-2025-10-18', 1, '2025-10-18', 1, '2025-10-18 12:18:09', 4, 1);

-- --------------------------------------------------------

--
-- Table structure for table `price_list_items`
--

CREATE TABLE `price_list_items` (
  `id` int(11) NOT NULL,
  `price` decimal(10,2) NOT NULL,
  `currency` varchar(5) NOT NULL DEFAULT 'RON',
  `price_return` decimal(10,2) DEFAULT NULL,
  `price_list_id` int(11) DEFAULT NULL,
  `from_station_id` int(11) NOT NULL,
  `to_station_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `price_list_items`
--

INSERT INTO `price_list_items` (`id`, `price`, `currency`, `price_return`, `price_list_id`, `from_station_id`, `to_station_id`) VALUES(1, 50.00, 'RON', NULL, 1, 7, 6);
INSERT INTO `price_list_items` (`id`, `price`, `currency`, `price_return`, `price_list_id`, `from_station_id`, `to_station_id`) VALUES(2, 50.00, 'RON', NULL, 2, 6, 8);
INSERT INTO `price_list_items` (`id`, `price`, `currency`, `price_return`, `price_list_id`, `from_station_id`, `to_station_id`) VALUES(4, 0.10, 'RON', NULL, 3, 7, 6);
INSERT INTO `price_list_items` (`id`, `price`, `currency`, `price_return`, `price_list_id`, `from_station_id`, `to_station_id`) VALUES(5, 100.00, 'RON', NULL, 4, 8, 3);

-- --------------------------------------------------------

--
-- Table structure for table `pricing_categories`
--

CREATE TABLE `pricing_categories` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `pricing_categories`
--

INSERT INTO `pricing_categories` (`id`, `name`, `description`, `active`) VALUES(1, 'Normal', 'Preț standard pentru bilete individuale', 1);
INSERT INTO `pricing_categories` (`id`, `name`, `description`, `active`) VALUES(2, 'Online', 'Preț standard pentru bilete online', 1);
INSERT INTO `pricing_categories` (`id`, `name`, `description`, `active`) VALUES(3, 'Elev', 'Preț standard pentru elevi', 1);
INSERT INTO `pricing_categories` (`id`, `name`, `description`, `active`) VALUES(4, 'Student', 'Preț standard pentru studenți', 1);

-- --------------------------------------------------------

--
-- Table structure for table `promo_codes`
--

CREATE TABLE `promo_codes` (
  `id` int(11) NOT NULL,
  `code` varchar(50) NOT NULL,
  `label` text NOT NULL,
  `type` enum('percent','fixed') NOT NULL,
  `value_off` decimal(7,2) NOT NULL,
  `valid_from` datetime DEFAULT NULL,
  `valid_to` datetime DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `channels` set('online','agent') NOT NULL DEFAULT 'online',
  `min_price` decimal(10,2) DEFAULT NULL,
  `max_discount` decimal(10,2) DEFAULT NULL,
  `max_total_uses` int(11) DEFAULT NULL,
  `max_uses_per_person` int(11) DEFAULT NULL,
  `combinable` tinyint(1) NOT NULL DEFAULT 0,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `promo_codes`
--

INSERT INTO `promo_codes` (`id`, `code`, `label`, `type`, `value_off`, `valid_from`, `valid_to`, `active`, `channels`, `min_price`, `max_discount`, `max_total_uses`, `max_uses_per_person`, `combinable`, `created_by`, `created_at`) VALUES(4, 'RED10', 'red', 'fixed', 20.00, '2025-10-17 21:07:00', '2025-10-18 21:08:00', 1, 'online,agent', NULL, NULL, 1, 1, 1, NULL, '2025-10-17 18:09:43');
INSERT INTO `promo_codes` (`id`, `code`, `label`, `type`, `value_off`, `valid_from`, `valid_to`, `active`, `channels`, `min_price`, `max_discount`, `max_total_uses`, `max_uses_per_person`, `combinable`, `created_by`, `created_at`) VALUES(5, 'GUGUBA', 'gu', 'fixed', 20.00, '2025-10-17 21:10:00', '2025-10-18 21:10:00', 1, 'online,agent', NULL, NULL, 1, 1, 1, NULL, '2025-10-17 18:10:35');

-- --------------------------------------------------------

--
-- Table structure for table `promo_code_hours`
--

CREATE TABLE `promo_code_hours` (
  `promo_code_id` int(11) NOT NULL,
  `start_time` time NOT NULL,
  `end_time` time NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `promo_code_routes`
--

CREATE TABLE `promo_code_routes` (
  `promo_code_id` int(11) NOT NULL,
  `route_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `promo_code_routes`
--

INSERT INTO `promo_code_routes` (`promo_code_id`, `route_id`) VALUES(4, 4);
INSERT INTO `promo_code_routes` (`promo_code_id`, `route_id`) VALUES(5, 4);

-- --------------------------------------------------------

--
-- Table structure for table `promo_code_schedules`
--

CREATE TABLE `promo_code_schedules` (
  `promo_code_id` int(11) NOT NULL,
  `route_schedule_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `promo_code_usages`
--

CREATE TABLE `promo_code_usages` (
  `id` int(11) NOT NULL,
  `promo_code_id` int(11) NOT NULL,
  `reservation_id` int(11) DEFAULT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `used_at` datetime NOT NULL DEFAULT current_timestamp(),
  `discount_amount` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `promo_code_weekdays`
--

CREATE TABLE `promo_code_weekdays` (
  `promo_code_id` int(11) NOT NULL,
  `weekday` tinyint(1) NOT NULL
) ;

-- --------------------------------------------------------

--
-- Table structure for table `reservations`
--

CREATE TABLE `reservations` (
  `id` int(11) NOT NULL,
  `trip_id` int(11) DEFAULT NULL,
  `seat_id` int(11) DEFAULT NULL,
  `person_id` int(11) DEFAULT NULL,
  `reservation_time` timestamp NULL DEFAULT current_timestamp(),
  `status` enum('active','cancelled') NOT NULL DEFAULT 'active',
  `observations` text DEFAULT NULL,
  `created_by` int(11) DEFAULT NULL,
  `board_station_id` int(11) NOT NULL,
  `exit_station_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `reservations`
--

INSERT INTO `reservations` (`id`, `trip_id`, `seat_id`, `person_id`, `reservation_time`, `status`, `observations`, `created_by`, `board_station_id`, `exit_station_id`) VALUES(84, 17130, 240, 61, '2025-10-21 11:06:22', 'cancelled', NULL, 1, 7, 6);
INSERT INTO `reservations` (`id`, `trip_id`, `seat_id`, `person_id`, `reservation_time`, `status`, `observations`, `created_by`, `board_station_id`, `exit_station_id`) VALUES(85, 17131, 240, 61, '2025-10-21 11:07:05', 'active', NULL, 1, 7, 6);
INSERT INTO `reservations` (`id`, `trip_id`, `seat_id`, `person_id`, `reservation_time`, `status`, `observations`, `created_by`, `board_station_id`, `exit_station_id`) VALUES(86, 17131, 241, 62, '2025-10-21 11:32:04', 'active', NULL, 1, 7, 6);
INSERT INTO `reservations` (`id`, `trip_id`, `seat_id`, `person_id`, `reservation_time`, `status`, `observations`, `created_by`, `board_station_id`, `exit_station_id`) VALUES(87, 17130, 240, 61, '2025-10-21 13:10:57', 'active', NULL, 1, 7, 6);
INSERT INTO `reservations` (`id`, `trip_id`, `seat_id`, `person_id`, `reservation_time`, `status`, `observations`, `created_by`, `board_station_id`, `exit_station_id`) VALUES(88, 17136, 63, 61, '2025-10-21 19:11:12', 'active', NULL, 1, 7, 6);
INSERT INTO `reservations` (`id`, `trip_id`, `seat_id`, `person_id`, `reservation_time`, `status`, `observations`, `created_by`, `board_station_id`, `exit_station_id`) VALUES(89, 17181, 240, 61, '2025-10-22 08:10:15', 'active', NULL, 1, 7, 6);

-- --------------------------------------------------------

--
-- Table structure for table `reservations_backup`
--

CREATE TABLE `reservations_backup` (
  `id` int(11) NOT NULL,
  `reservation_id` int(11) DEFAULT NULL,
  `trip_id` int(11) DEFAULT NULL,
  `seat_id` int(11) DEFAULT NULL,
  `label` text DEFAULT NULL,
  `person_id` int(11) DEFAULT NULL,
  `backup_time` datetime DEFAULT current_timestamp(),
  `old_vehicle_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `reservations_backup`
--

INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(3, 58, 17082, 241, '', 44, '2025-10-19 19:33:09', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(4, 62, 17082, 240, '', 44, '2025-10-20 00:11:46', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(5, 58, 17082, 241, '', 44, '2025-10-20 00:16:10', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(6, 61, 17082, 241, '', 47, '2025-10-20 00:16:16', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(7, 65, 17106, 240, '', 50, '2025-10-20 00:18:00', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(8, 66, 17106, 240, '', 51, '2025-10-20 00:18:30', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(9, 66, 17106, 240, '', 51, '2025-10-20 00:22:06', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(10, 67, 17106, 240, '', 52, '2025-10-20 00:22:06', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(11, 68, 17106, 240, '', 53, '2025-10-20 00:22:26', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(12, 69, 17106, 240, '', 54, '2025-10-20 00:23:06', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(13, 68, 17106, 240, '', 53, '2025-10-20 23:13:24', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(14, 69, 17106, 240, '', 54, '2025-10-20 23:13:24', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(15, 73, 17106, 240, '', 55, '2025-10-20 23:13:24', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(16, 76, 17106, 244, '', 57, '2025-10-20 23:59:40', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(17, 78, 17108, 241, '', 57, '2025-10-21 00:00:39', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(18, 75, 17106, 240, '', 56, '2025-10-21 10:34:11', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(19, 75, 17106, 240, '', 56, '2025-10-21 10:37:13', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(20, 82, 17130, 242, '', 60, '2025-10-21 14:03:59', NULL);
INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES(21, 84, 17130, 240, '', 61, '2025-10-21 14:07:05', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `reservation_discounts`
--

CREATE TABLE `reservation_discounts` (
  `id` int(11) NOT NULL,
  `reservation_id` int(11) NOT NULL,
  `discount_type_id` int(11) DEFAULT NULL,
  `promo_code_id` int(11) DEFAULT NULL,
  `discount_amount` decimal(10,2) NOT NULL,
  `applied_at` datetime NOT NULL DEFAULT current_timestamp(),
  `discount_snapshot` decimal(5,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `reservation_discounts`
--

INSERT INTO `reservation_discounts` (`id`, `reservation_id`, `discount_type_id`, `promo_code_id`, `discount_amount`, `applied_at`, `discount_snapshot`) VALUES(4, 71, 2, NULL, 0.00, '2025-10-20 18:37:06', 50.00);
INSERT INTO `reservation_discounts` (`id`, `reservation_id`, `discount_type_id`, `promo_code_id`, `discount_amount`, `applied_at`, `discount_snapshot`) VALUES(5, 72, 2, NULL, 0.00, '2025-10-20 18:37:21', 50.00);
INSERT INTO `reservation_discounts` (`id`, `reservation_id`, `discount_type_id`, `promo_code_id`, `discount_amount`, `applied_at`, `discount_snapshot`) VALUES(6, 82, 2, NULL, 0.05, '2025-10-21 14:03:07', 50.00);
INSERT INTO `reservation_discounts` (`id`, `reservation_id`, `discount_type_id`, `promo_code_id`, `discount_amount`, `applied_at`, `discount_snapshot`) VALUES(7, 84, 2, NULL, 0.05, '2025-10-21 14:06:22', 50.00);

-- --------------------------------------------------------

--
-- Table structure for table `reservation_events`
--

CREATE TABLE `reservation_events` (
  `id` int(11) NOT NULL,
  `reservation_id` int(11) NOT NULL,
  `action` enum('create','update','move','cancel','uncancel','delete','pay','refund') NOT NULL,
  `actor_id` int(11) DEFAULT NULL,
  `details` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`details`)),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `reservation_pricing`
--

CREATE TABLE `reservation_pricing` (
  `reservation_id` int(11) NOT NULL,
  `price_value` decimal(10,2) NOT NULL,
  `price_list_id` int(11) NOT NULL,
  `pricing_category_id` int(11) NOT NULL,
  `booking_channel` enum('online','agent') NOT NULL DEFAULT 'agent',
  `employee_id` int(11) NOT NULL DEFAULT 12,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `reservation_pricing`
--

INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(74, 0.10, 3, 1, 'agent', 1, '2025-10-20 18:38:22', '2025-10-20 18:38:22');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(75, 0.10, 3, 1, 'agent', 1, '2025-10-20 23:15:10', '2025-10-20 23:15:10');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(76, 0.10, 3, 1, 'agent', 1, '2025-10-20 23:54:43', '2025-10-20 23:54:43');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(77, 0.10, 3, 1, 'agent', 1, '2025-10-20 23:59:40', '2025-10-20 23:59:40');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(78, 0.10, 3, 1, 'agent', 1, '2025-10-21 00:00:28', '2025-10-21 00:00:28');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(79, 0.10, 3, 1, 'agent', 1, '2025-10-21 10:37:13', '2025-10-21 10:37:13');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(80, 0.10, 3, 1, 'agent', 1, '2025-10-21 13:40:31', '2025-10-21 13:40:31');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(81, 0.10, 3, 1, 'agent', 1, '2025-10-21 13:47:55', '2025-10-21 13:47:55');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(82, 0.05, 3, 1, 'agent', 1, '2025-10-21 14:03:07', '2025-10-21 14:03:07');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(83, 0.05, 3, 1, 'agent', 1, '2025-10-21 14:03:59', '2025-10-21 14:03:59');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(84, 0.05, 3, 1, 'agent', 1, '2025-10-21 14:06:22', '2025-10-21 14:06:22');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(85, 0.05, 3, 1, 'agent', 1, '2025-10-21 14:07:05', '2025-10-21 14:07:05');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(86, 0.10, 3, 1, 'agent', 1, '2025-10-21 14:32:04', '2025-10-21 14:32:04');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(87, 0.10, 3, 1, 'agent', 1, '2025-10-21 16:10:57', '2025-10-21 16:10:57');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(88, 0.10, 3, 1, 'agent', 1, '2025-10-21 22:11:13', '2025-10-21 22:11:13');
INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES(89, 0.10, 3, 1, 'agent', 1, '2025-10-22 11:10:15', '2025-10-22 11:10:15');

-- --------------------------------------------------------

--
-- Table structure for table `routes`
--

CREATE TABLE `routes` (
  `id` int(11) NOT NULL,
  `name` text NOT NULL,
  `order_index` int(11) DEFAULT NULL,
  `opposite_route_id` int(11) DEFAULT NULL,
  `direction` enum('tur','retur') NOT NULL DEFAULT 'tur'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `routes`
--

INSERT INTO `routes` (`id`, `name`, `order_index`, `opposite_route_id`, `direction`) VALUES(1, 'Botoșani – Iași', 1, 7, 'tur');
INSERT INTO `routes` (`id`, `name`, `order_index`, `opposite_route_id`, `direction`) VALUES(2, 'Rădăuți – Iași', 10, 8, 'tur');
INSERT INTO `routes` (`id`, `name`, `order_index`, `opposite_route_id`, `direction`) VALUES(3, 'Botoșani – Brașov', 7, 5, 'tur');
INSERT INTO `routes` (`id`, `name`, `order_index`, `opposite_route_id`, `direction`) VALUES(4, 'Botoșani – București', 3, 6, 'tur');
INSERT INTO `routes` (`id`, `name`, `order_index`, `opposite_route_id`, `direction`) VALUES(5, 'Brașov – Botoșani', 8, 3, 'retur');
INSERT INTO `routes` (`id`, `name`, `order_index`, `opposite_route_id`, `direction`) VALUES(6, 'București – Botoșani', 4, 4, 'retur');
INSERT INTO `routes` (`id`, `name`, `order_index`, `opposite_route_id`, `direction`) VALUES(7, 'Iași – Botoșani', 2, 1, 'retur');
INSERT INTO `routes` (`id`, `name`, `order_index`, `opposite_route_id`, `direction`) VALUES(8, 'Iași – Rădăuți', 9, 2, 'retur');
INSERT INTO `routes` (`id`, `name`, `order_index`, `opposite_route_id`, `direction`) VALUES(9, 'Dorohoi – Botoșani – Iași', 5, 10, 'tur');
INSERT INTO `routes` (`id`, `name`, `order_index`, `opposite_route_id`, `direction`) VALUES(10, 'Iași – Botoșani – Dorohoi', 6, 9, 'retur');

-- --------------------------------------------------------

--
-- Table structure for table `route_schedules`
--

CREATE TABLE `route_schedules` (
  `id` int(11) NOT NULL,
  `route_id` int(11) NOT NULL,
  `departure` time NOT NULL,
  `operator_id` int(11) NOT NULL,
  `direction` varchar(10) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `route_schedules`
--

INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(1, 1, '06:00:00', 1, 'tur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(2, 1, '07:00:00', 1, 'tur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(3, 1, '09:00:00', 1, 'tur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(4, 1, '11:30:00', 2, 'retur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(5, 1, '13:30:00', 1, 'tur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(6, 1, '15:30:00', 1, 'tur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(7, 1, '17:00:00', 2, 'retur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(8, 1, '19:00:00', 2, 'retur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(9, 2, '08:00:00', 2, 'tur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(10, 3, '08:00:00', 2, 'tur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(11, 4, '21:00:00', 1, 'tur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(12, 5, '16:00:00', 2, 'retur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(13, 6, '14:00:00', 1, 'retur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(14, 7, '07:00:00', 2, 'tur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(15, 7, '10:00:00', 1, 'retur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(16, 7, '12:00:00', 1, 'retur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(17, 7, '13:00:00', 2, 'tur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(18, 7, '14:00:00', 1, 'retur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(19, 7, '15:00:00', 2, 'tur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(20, 7, '17:00:00', 1, 'retur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(21, 7, '19:00:00', 1, 'retur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(22, 8, '16:00:00', 2, 'retur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(23, 9, '07:00:00', 2, 'tur');
INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES(24, 10, '11:00:00', 2, 'retur');

-- --------------------------------------------------------

--
-- Table structure for table `route_schedule_discounts`
--

CREATE TABLE `route_schedule_discounts` (
  `discount_type_id` int(11) NOT NULL,
  `route_schedule_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `route_schedule_discounts`
--

INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 1);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 2);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 3);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 4);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 5);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 6);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 7);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 8);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 10);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 11);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 12);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 13);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 14);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 15);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 16);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 17);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 18);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 19);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 20);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 21);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 23);
INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES(2, 24);

-- --------------------------------------------------------

--
-- Table structure for table `route_stations`
--

CREATE TABLE `route_stations` (
  `id` int(11) NOT NULL,
  `route_id` int(11) NOT NULL,
  `station_id` int(11) NOT NULL,
  `sequence` int(11) NOT NULL,
  `distance_from_previous_km` decimal(6,2) DEFAULT NULL,
  `travel_time_from_previous_minutes` int(11) DEFAULT NULL,
  `dwell_time_minutes` int(11) DEFAULT 0,
  `geofence_type` enum('circle','polygon') NOT NULL DEFAULT 'circle',
  `geofence_radius_m` decimal(10,2) DEFAULT NULL,
  `geofence_polygon` geometry DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `route_stations`
--

INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(16, 4, 8, 1, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(17, 4, 2, 2, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(18, 4, 3, 3, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(19, 5, 4, 1, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(20, 5, 15, 2, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(21, 5, 1, 3, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(22, 5, 8, 4, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(27, 1, 7, 1, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:09:51', '2025-10-11 18:09:51');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(28, 1, 14, 2, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:09:51', '2025-10-11 18:09:51');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(29, 1, 5, 3, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:09:51', '2025-10-11 18:09:51');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(30, 1, 11, 4, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:09:51', '2025-10-11 18:09:51');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(31, 1, 6, 5, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:09:51', '2025-10-11 18:09:51');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(32, 6, 3, 1, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-10-11 18:10:27', '2025-10-11 18:10:27');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(33, 6, 2, 2, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:10:27', '2025-10-11 18:10:27');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(34, 6, 7, 3, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:10:27', '2025-10-11 18:10:27');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(38, 7, 6, 1, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:04', '2025-10-11 18:11:04');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(39, 7, 11, 2, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:04', '2025-10-11 18:11:04');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(40, 7, 7, 3, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:04', '2025-10-11 18:11:04');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(41, 10, 6, 1, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:22', '2025-10-11 18:11:22');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(42, 10, 7, 2, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:22', '2025-10-11 18:11:22');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(43, 10, 9, 3, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:22', '2025-10-11 18:11:22');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(44, 8, 6, 1, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:35', '2025-10-11 18:11:35');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(45, 8, 8, 2, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:35', '2025-10-11 18:11:35');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(49, 2, 8, 1, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:47', '2025-10-11 18:11:47');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(50, 2, 10, 2, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:47', '2025-10-11 18:11:47');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(51, 2, 6, 3, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:47', '2025-10-11 18:11:47');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(64, 3, 7, 1, NULL, NULL, 0, 'polygon', NULL, 0xe6100000010300000001000000050000006c1857902aac3a40282cc9f4d7e14740d18829ce08b83a400354ba798cdd4740f8cced5a53a53a40956f5185fbdb47405b5779f82ba43a40536ee75142e247406c1857902aac3a40282cc9f4d7e14740, '2025-10-12 18:49:20', '2025-10-12 18:49:20');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(65, 3, 5, 2, NULL, NULL, 0, 'circle', 2000.00, NULL, '2025-10-12 18:49:20', '2025-10-12 18:49:20');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(66, 3, 4, 3, NULL, NULL, 0, 'circle', 2000.00, NULL, '2025-10-12 18:49:20', '2025-10-12 18:49:20');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(67, 9, 9, 1, NULL, NULL, 0, 'circle', 683.00, NULL, '2025-10-12 18:53:23', '2025-10-12 18:53:23');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(68, 9, 5, 2, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-10-12 18:53:23', '2025-10-12 18:53:23');
INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES(69, 9, 6, 3, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-10-12 18:53:23', '2025-10-12 18:53:23');

-- --------------------------------------------------------

--
-- Table structure for table `schedule_exceptions`
--

CREATE TABLE `schedule_exceptions` (
  `id` int(11) NOT NULL,
  `schedule_id` int(11) NOT NULL,
  `exception_date` date DEFAULT NULL,
  `weekday` tinyint(3) UNSIGNED DEFAULT NULL,
  `disable_run` tinyint(1) NOT NULL DEFAULT 0,
  `disable_online` tinyint(1) NOT NULL DEFAULT 0,
  `created_by_employee_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `schedule_exceptions`
--

INSERT INTO `schedule_exceptions` (`id`, `schedule_id`, `exception_date`, `weekday`, `disable_run`, `disable_online`, `created_by_employee_id`, `created_at`) VALUES(3, 1, '2025-10-15', NULL, 0, 0, 12, '2025-10-12 19:02:12');

-- --------------------------------------------------------

--
-- Table structure for table `seats`
--

CREATE TABLE `seats` (
  `id` int(11) NOT NULL,
  `vehicle_id` int(11) DEFAULT NULL,
  `seat_number` int(11) DEFAULT NULL,
  `position` varchar(20) DEFAULT NULL,
  `row` int(11) NOT NULL,
  `seat_col` int(11) NOT NULL,
  `is_available` tinyint(1) NOT NULL DEFAULT 1,
  `label` text DEFAULT NULL,
  `seat_type` enum('normal','driver','guide','foldable','wheelchair') NOT NULL DEFAULT 'normal',
  `pair_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `seats`
--

INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(61, 1, 0, NULL, 0, 1, 1, 'Șofer', 'driver', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(62, 1, 20, NULL, 0, 4, 1, '20', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(63, 1, 1, NULL, 1, 1, 1, '1', 'normal', 1);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(64, 1, 2, NULL, 1, 2, 1, '2', 'normal', 1);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(65, 1, 3, NULL, 1, 4, 1, '3', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(66, 1, 4, NULL, 2, 1, 1, '4', 'normal', 2);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(67, 1, 5, NULL, 2, 2, 1, '5', 'normal', 2);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(68, 1, 6, NULL, 2, 4, 1, '6', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(69, 1, 7, NULL, 3, 1, 1, '7', 'normal', 8);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(70, 1, 8, NULL, 3, 2, 1, '8', 'normal', 7);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(71, 1, 9, NULL, 3, 4, 1, '9', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(72, 1, 10, NULL, 4, 1, 1, '10', 'normal', 11);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(73, 1, 11, NULL, 4, 2, 1, '11', 'normal', 10);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(74, 1, 12, NULL, 4, 4, 1, '12', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(75, 1, 13, NULL, 5, 1, 1, '13', 'normal', 14);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(76, 1, 14, NULL, 5, 2, 1, '14', 'normal', 13);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(84, 3, 0, NULL, 0, 1, 1, 'Șofer', 'driver', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(85, 3, 52, NULL, 0, 4, 1, 'Ghid', 'guide', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(86, 3, 1, NULL, 1, 1, 1, '1', 'normal', 2);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(87, 3, 2, NULL, 1, 2, 1, '2', 'normal', 1);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(88, 3, 3, NULL, 2, 1, 1, '3', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(89, 3, 4, NULL, 2, 2, 1, '4', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(90, 3, 5, NULL, 3, 1, 1, '5', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(91, 3, 6, NULL, 3, 2, 1, '6', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(92, 3, 7, NULL, 4, 1, 1, '7', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(93, 3, 8, NULL, 4, 2, 1, '8', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(94, 3, 9, NULL, 5, 1, 1, '9', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(95, 3, 10, NULL, 5, 2, 1, '10', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(96, 3, 11, NULL, 6, 1, 1, '11', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(97, 3, 12, NULL, 6, 2, 1, '12', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(98, 3, 13, NULL, 7, 1, 1, '13', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(99, 3, 14, NULL, 7, 2, 1, '14', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(100, 3, 15, NULL, 8, 1, 1, '15', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(101, 3, 16, NULL, 8, 2, 1, '16', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(102, 3, 17, NULL, 9, 1, 1, '17', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(103, 3, 18, NULL, 9, 2, 1, '18', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(104, 3, 19, NULL, 10, 1, 1, '19', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(105, 3, 20, NULL, 10, 2, 1, '20', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(106, 3, 21, NULL, 11, 1, 1, '21', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(107, 3, 22, NULL, 11, 2, 1, '22', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(108, 3, 23, NULL, 12, 1, 1, '23', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(109, 3, 24, NULL, 12, 2, 1, '24', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(110, 3, 25, NULL, 13, 1, 1, '25', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(111, 3, 26, NULL, 13, 2, 1, '26', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(112, 3, 27, NULL, 1, 3, 1, '27', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(113, 3, 28, NULL, 1, 4, 1, '28', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(114, 3, 29, NULL, 2, 3, 1, '29', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(115, 3, 30, NULL, 2, 4, 1, '30', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(116, 3, 31, NULL, 3, 3, 1, '31', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(117, 3, 32, NULL, 3, 4, 1, '32', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(118, 3, 33, NULL, 4, 3, 1, '33', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(119, 3, 34, NULL, 4, 4, 1, '34', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(120, 3, 35, NULL, 5, 3, 1, '35', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(121, 3, 36, NULL, 5, 4, 1, '36', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(122, 3, 37, NULL, 6, 3, 1, '37', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(123, 3, 38, NULL, 6, 4, 1, '38', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(124, 3, 39, NULL, 8, 3, 1, '39', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(125, 3, 40, NULL, 8, 4, 1, '40', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(126, 3, 41, NULL, 9, 3, 1, '41', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(127, 3, 42, NULL, 9, 4, 1, '42', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(128, 3, 43, NULL, 10, 3, 1, '43', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(129, 3, 44, NULL, 10, 4, 1, '44', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(130, 3, 45, NULL, 11, 3, 1, '45', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(131, 3, 46, NULL, 11, 4, 1, '46', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(132, 3, 47, NULL, 12, 3, 1, '47', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(133, 3, 48, NULL, 12, 4, 1, '48', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(134, 3, 49, NULL, 13, 3, 1, '49', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(135, 3, 50, NULL, 13, 4, 1, '50', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(187, 2, 0, NULL, 0, 1, 1, 'Șofer', 'driver', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(188, 2, 50, NULL, 0, 5, 1, '50', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(189, 2, 1, NULL, 1, 1, 1, '1', 'normal', 1);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(190, 2, 2, NULL, 1, 2, 1, '2', 'normal', 1);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(191, 2, 3, NULL, 1, 4, 1, '3', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(192, 2, 4, NULL, 1, 5, 1, '4', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(193, 2, 5, NULL, 2, 1, 1, '5', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(194, 2, 6, NULL, 2, 2, 1, '6', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(195, 2, 7, NULL, 2, 4, 1, '7', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(196, 2, 8, NULL, 2, 5, 1, '8', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(197, 2, 9, NULL, 3, 1, 1, '9', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(198, 2, 10, NULL, 3, 2, 1, '10', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(199, 2, 11, NULL, 3, 4, 1, '11', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(200, 2, 12, NULL, 3, 5, 1, '12', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(201, 2, 13, NULL, 4, 1, 1, '13', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(202, 2, 14, NULL, 4, 2, 1, '14', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(203, 2, 15, NULL, 4, 4, 1, '15', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(204, 2, 16, NULL, 4, 5, 1, '16', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(205, 2, 17, NULL, 5, 1, 1, '17', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(206, 2, 18, NULL, 5, 2, 1, '18', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(207, 2, 19, NULL, 5, 4, 1, '19', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(208, 2, 20, NULL, 5, 5, 1, '20', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(209, 2, 21, NULL, 6, 1, 1, '21', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(210, 2, 22, NULL, 6, 2, 1, '22', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(211, 2, 23, NULL, 7, 1, 1, '23', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(212, 2, 24, NULL, 7, 2, 1, '24', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(213, 2, 25, NULL, 8, 1, 1, '25', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(214, 2, 26, NULL, 8, 2, 1, '26', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(215, 2, 27, NULL, 8, 4, 1, '27', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(216, 2, 28, NULL, 8, 5, 1, '28', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(217, 2, 29, NULL, 9, 1, 1, '29', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(218, 2, 30, NULL, 9, 2, 1, '30', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(219, 2, 31, NULL, 9, 4, 1, '31', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(220, 2, 32, NULL, 9, 5, 1, '32', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(221, 2, 33, NULL, 10, 1, 1, '33', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(222, 2, 34, NULL, 10, 2, 1, '34', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(223, 2, 35, NULL, 10, 4, 1, '35', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(224, 2, 36, NULL, 10, 5, 1, '36', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(225, 2, 37, NULL, 11, 1, 1, '37', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(226, 2, 38, NULL, 11, 2, 1, '38', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(227, 2, 39, NULL, 11, 4, 1, '39', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(228, 2, 40, NULL, 11, 5, 1, '40', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(229, 2, 41, NULL, 12, 1, 1, '41', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(230, 2, 42, NULL, 12, 2, 1, '42', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(231, 2, 43, NULL, 12, 4, 1, '43', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(232, 2, 44, NULL, 12, 5, 1, '44', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(233, 2, 45, NULL, 13, 1, 1, '45', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(234, 2, 46, NULL, 13, 2, 1, '46', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(235, 2, 47, NULL, 13, 3, 1, '47', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(236, 2, 48, NULL, 13, 4, 1, '48', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(237, 2, 49, NULL, 13, 5, 1, '49', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(238, 4, 0, NULL, 0, 1, 1, 'Șofer', 'driver', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(239, 4, 20, NULL, 0, 4, 1, '20', 'guide', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(240, 4, 1, NULL, 1, 1, 1, '1', 'normal', 1);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(241, 4, 2, NULL, 1, 2, 1, '2', 'normal', 1);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(242, 4, 3, NULL, 1, 4, 1, '3', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(243, 4, 4, NULL, 2, 1, 1, '4', 'normal', 2);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(244, 4, 5, NULL, 2, 2, 1, '5', 'normal', 2);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(245, 4, 6, NULL, 2, 4, 1, '6', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(246, 4, 7, NULL, 3, 1, 1, '7', 'normal', 3);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(247, 4, 8, NULL, 3, 2, 1, '8', 'normal', 3);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(248, 4, 9, NULL, 3, 4, 1, '9', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(249, 4, 10, NULL, 4, 1, 1, '10', 'normal', 4);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(250, 4, 11, NULL, 4, 2, 1, '11', 'normal', 4);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(251, 4, 12, NULL, 4, 4, 1, '12', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(252, 4, 13, NULL, 5, 1, 1, '13', 'normal', 5);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(253, 4, 14, NULL, 5, 2, 1, '14', 'normal', 5);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(254, 4, 15, NULL, 5, 4, 1, '15', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(255, 4, 16, NULL, 6, 1, 1, '16', 'normal', 6);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(256, 4, 17, NULL, 6, 2, 1, '17', 'normal', 6);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(257, 4, 18, NULL, 6, 3, 1, '18', 'normal', 6);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(258, 4, 19, NULL, 6, 4, 1, '19', 'normal', 6);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(259, 5, 0, NULL, 0, 1, 1, 'Șofer', 'driver', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(260, 5, 20, NULL, 0, 4, 1, '20', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(261, 5, 1, NULL, 1, 1, 1, '1', 'normal', 1);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(262, 5, 2, NULL, 1, 2, 1, '2', 'normal', 1);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(263, 5, 3, NULL, 1, 4, 1, '3', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(264, 5, 4, NULL, 2, 1, 1, '4', 'normal', 2);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(265, 5, 5, NULL, 2, 2, 1, '5', 'normal', 2);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(266, 5, 6, NULL, 2, 4, 1, '6', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(267, 5, 7, NULL, 3, 1, 1, '7', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(268, 5, 8, NULL, 3, 2, 1, '8', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(269, 5, 9, NULL, 3, 4, 1, '9', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(270, 5, 10, NULL, 4, 1, 1, '10', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(271, 5, 11, NULL, 4, 2, 1, '11', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(272, 5, 12, NULL, 4, 4, 1, '12', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(273, 5, 13, NULL, 5, 1, 1, '13', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(274, 5, 14, NULL, 5, 2, 1, '14', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(275, 5, 15, NULL, 5, 4, 1, '15', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(276, 5, 16, NULL, 6, 1, 1, '16', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(277, 5, 17, NULL, 6, 2, 1, '17', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(278, 5, 18, NULL, 6, 3, 1, '18', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(279, 5, 19, NULL, 6, 4, 1, '19', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(282, 1, NULL, NULL, 5, 4, 1, '15', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(283, 1, NULL, NULL, 6, 1, 1, '16', 'normal', 17);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(284, 1, NULL, NULL, 6, 2, 1, '17', 'normal', 16);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(285, 1, NULL, NULL, 6, 4, 1, '18', 'normal', NULL);
INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`, `seat_type`, `pair_id`) VALUES(286, 1, NULL, NULL, 7, 1, 1, '19', 'normal', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `sessions`
--

CREATE TABLE `sessions` (
  `id` int(11) NOT NULL,
  `employee_id` int(11) NOT NULL,
  `token_hash` varchar(255) NOT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  `ip` varchar(64) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `expires_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `rotated_from` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `sessions`
--

INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(1, 1, '1f0f55029b3888988ae25e7885040fe6d0f83676d21ec89bd697db5b5174dc2a', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 08:27:38', '2025-11-18 08:27:38', '2025-10-19 08:27:43', NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(2, 1, '27a23509c1092d44421d3609552f7b50acb89b895df101536cc8facc31c17343', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 08:27:45', '2025-11-18 08:27:45', '2025-10-19 08:28:59', NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(3, 1, '6900f3940e83c7029eb7fb23d02f2c1cc2e64c2f5e86d3dd53164946d02f3ea9', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 08:30:22', '2025-11-18 08:30:22', '2025-10-19 08:38:45', NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(4, 1, '566d1b47b071589beb6e8b1ce4fe24ba98e0ca301a525e33da773b529d4d5977', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 08:38:54', '2025-11-18 08:38:54', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(5, 1, '49c1a658e6c635cb998b939980a912988efd33b4b552c208c70581eaab360db4', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 08:40:13', '2025-11-18 08:40:13', '2025-10-19 08:40:16', NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(6, 5, 'c54d17571bd2204fb07593745828159918f911044e07417efbd48a815901ed14', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 08:40:26', '2025-11-18 08:40:26', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(7, 1, '7d85f0d8f7d988c89fc84818772da1c0f9429aa50f994b711045dcbba21a1daf', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 09:05:10', '2025-11-18 09:05:10', '2025-10-19 09:19:53', NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(8, 5, '91b3a547a5cadf3f3e6f563cea279e61960fe10fc8e2f1fee7673d51735db01e', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 09:19:56', '2025-11-18 09:19:56', '2025-10-19 09:29:45', NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(9, 5, '3b645dab18320830f5b7cb0329b9e18d7f03a0203123ad97f65b6d7878ede3f1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 09:29:47', '2025-11-18 09:29:47', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(10, 5, 'b1042abfe882e5fe2c79fd9de162e64278190a14132ce5944efa5f902d4eac4d', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 09:49:42', '2025-11-18 09:49:42', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(11, 5, 'df18cc4ddec0955279fde2205ca6866a7a38b7cd286b06b2a4a2b77d9aeba3ba', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 10:04:45', '2025-11-18 10:04:45', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(12, 5, 'bd41d89391baf6c4d71f1a125acb42f3b34cda5cabaf938c546b2916732b605c', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 10:45:36', '2025-11-18 10:45:36', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(13, 5, '1b2128a5f456de26f66fd7494b478c8fbbe50c262b2bb997b9c11b82e1427f60', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 11:07:10', '2025-11-18 11:07:10', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(14, 5, 'c128f6e74a3d9940618f49333196903d682c08507fcbd8db759e5a26b398f18a', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 11:31:41', '2025-11-18 11:31:41', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(15, 5, '07a50b67dce095576e88c82785d58d2fe111cb51b3c6c819f856befb78fa3d6f', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 11:57:23', '2025-11-18 11:57:23', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(16, 5, '9be97620cddb38d0746354b8e79cd80a833d4e5c9ec435f5f885a65ef953935a', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 12:22:27', '2025-11-18 12:22:27', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(17, 5, '4dbc16fa8d88b884b737e317a37d25399ce90d75495ee1b04480d0e4b71f2fdc', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 12:38:23', '2025-11-18 12:38:23', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(18, 5, 'fd1461ec5f5d3155aef0cd4f50337b89d79326c460a3e1dabf208c340036292a', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 12:53:38', '2025-11-18 12:53:38', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(19, 5, '3c029f4b1ee17aff59d1eec08c7ea9191162f1302d4d757b28d379966f2f7b6e', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 13:14:07', '2025-11-18 13:14:07', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(20, 5, 'e5ff7575ab887720a7610289d0eb6ed419d1f94ccd89ef125d5e4505adb0dcad', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 18:31:04', '2025-11-18 18:31:04', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(21, 5, 'a9af48b7ef9f8ee96c01dcb33a680bfd699cad98293f58c83439f3b1c86847c2', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 18:46:29', '2025-11-18 18:46:29', '2025-10-19 23:55:00', NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(22, 5, 'bf50b0d4d095d78bbc6a536ac288626bbf0b241f18ba35675937a7bd53b640ed', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-19 23:55:02', '2025-11-18 23:55:02', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(23, 5, '68e83d4e24de94ec955ee221821dee6da690ae61cd408aaffe81d1ba40cb33da', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-20 17:59:44', '2025-11-19 17:59:44', '2025-10-20 18:26:20', NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(24, 1, '0d186b4721c1fb51a02a62c04ad52aeb6a5a14b14ff09953885c94caea4df16f', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-20 18:26:24', '2025-11-19 18:26:24', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(25, 1, 'd267d410542a2bda406def8752351f91592cbe8d0d0516063d842c8a00bcec10', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-21 10:25:08', '2025-11-20 10:25:08', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(26, 1, '43a8d6b6c8f588ec9077b15c00979b15133331cf1ec30dd952cb4cbc46090d6d', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-21 10:33:58', '2025-11-20 10:33:58', '2025-10-21 16:01:29', NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(27, 1, '229e6ac2e4abe550f45b20d098b9b0f34fb95af19b7027757331bd6c8b96cfed', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-21 16:01:30', '2025-11-20 16:01:30', '2025-10-21 16:07:02', NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(28, 1, 'b35cc3cb71fc13d92d1849e7894693b6a248fff3a1c2cf2914610674d206a84b', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-21 16:10:19', '2025-11-20 16:10:19', NULL, NULL);
INSERT INTO `sessions` (`id`, `employee_id`, `token_hash`, `user_agent`, `ip`, `created_at`, `expires_at`, `revoked_at`, `rotated_from`) VALUES(29, 1, '85e7ccb6186f0a9394341d735d9dd0d70d4fed63c97b33a884c737cd4761bdcc', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0', '127.0.0.1', '2025-10-22 11:10:04', '2025-11-21 11:10:04', NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `stations`
--

CREATE TABLE `stations` (
  `id` int(11) NOT NULL,
  `name` text NOT NULL,
  `locality` text DEFAULT NULL,
  `county` text DEFAULT NULL,
  `latitude` decimal(11,8) DEFAULT NULL,
  `longitude` decimal(11,8) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `stations`
--

INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(1, 'Suceava', 'Suceava', NULL, 47.64622921, 26.25683733, '2025-09-23 20:49:00', '2025-10-04 15:07:52');
INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(2, 'Focșani', 'Focșani', NULL, 45.69303229, 27.19685926, '2025-09-23 20:49:00', '2025-10-04 15:06:43');
INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(3, 'București', 'București', NULL, 44.43302028, 26.10429666, '2025-09-23 20:49:00', '2025-10-04 15:05:32');
INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(4, 'Brașov', 'Brașov', NULL, 45.64571325, 25.57928619, '2025-09-23 20:49:00', '2025-10-04 15:05:44');
INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(5, 'Flamanzi', 'Flamanzi', NULL, 47.56004767, 26.88260433, '2025-09-23 20:49:00', '2025-10-04 15:06:34');
INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(6, 'Iași', 'Iași', NULL, 47.15221227, 27.60088813, '2025-09-23 20:49:00', '2025-10-04 15:07:23');
INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(7, 'Botoșani', 'Botoșani', NULL, 47.74559429, 26.66634352, '2025-09-23 20:49:00', '2025-10-04 15:08:11');
INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(8, 'Rădăuți', 'Rădăuți', NULL, 47.84576105, 25.92324273, '2025-09-23 20:49:00', '2025-10-04 15:07:44');
INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(9, 'Dorohoi', 'Dorohoi', NULL, 47.95282338, 26.39650703, '2025-09-23 20:49:00', '2025-10-04 15:06:25');
INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(10, 'Șendriceni', 'Șendriceni', NULL, 47.77842032, 26.39675549, '2025-09-23 20:49:00', '2025-10-04 15:08:01');
INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(11, 'Rădeni', 'Rădeni', NULL, 47.51324461, 26.90207136, '2025-09-23 20:49:00', '2025-10-04 15:07:36');
INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(12, 'Frumușica', 'Frumușica', NULL, 47.53052291, 26.89955637, '2025-09-23 20:49:00', '2025-10-04 15:06:55');
INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(14, 'Buda', 'Buda', NULL, 47.62720367, 26.81294511, '2025-09-23 20:49:00', '2025-10-04 15:05:58');
INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES(15, 'Bacău', 'Bacău', '', 46.55541503, 26.94994927, '2025-09-23 20:49:00', '2025-10-11 17:44:16');

-- --------------------------------------------------------

--
-- Table structure for table `traveler_defaults`
--

CREATE TABLE `traveler_defaults` (
  `id` int(11) NOT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `route_id` int(11) DEFAULT NULL,
  `use_count` int(11) DEFAULT 0,
  `last_used_at` datetime DEFAULT NULL,
  `board_station_id` int(11) DEFAULT NULL,
  `exit_station_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `traveler_defaults`
--

INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(1, '6543546546', 1, 1, '2025-10-16 13:10:15', 14, 6);
INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(2, '6846565465', 1, 1, '2025-10-16 13:10:24', 7, 14);
INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(3, '0743171315', 1, 7, '2025-10-20 23:15:10', 7, 6);
INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(4, '0743171316', 1, 1, '2025-10-16 13:18:53', 14, 6);
INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(5, '1234567890', 1, 16, '2025-10-22 11:10:15', 7, 6);
INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(6, '0743171315', 4, 1, '2025-10-18 13:24:07', 8, 3);
INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(7, '0743171315', 7, 3, '2025-10-20 18:37:21', 6, 7);
INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(8, '7894561230', 1, 1, '2025-10-19 19:34:33', 7, 6);
INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(9, '0742151894', 1, 1, '2025-10-21 13:42:06', 7, 6);
INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(10, '7894561237', 1, 1, '2025-10-21 13:47:55', 7, 6);
INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(11, '789456123654', 1, 1, '2025-10-21 14:03:07', 7, 6);
INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(12, '12345678901', 1, 3, '2025-10-21 14:31:38', 7, 6);
INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(13, '45678974984', 1, 1, '2025-10-21 14:32:11', 7, 6);
INSERT INTO `traveler_defaults` (`id`, `phone`, `route_id`, `use_count`, `last_used_at`, `board_station_id`, `exit_station_id`) VALUES(14, '7894565651', 1, 1, '2025-10-21 14:55:23', 7, 6);

-- --------------------------------------------------------

--
-- Table structure for table `trips`
--

CREATE TABLE `trips` (
  `id` int(11) NOT NULL,
  `route_id` int(11) DEFAULT NULL,
  `vehicle_id` int(11) DEFAULT NULL,
  `date` date DEFAULT NULL,
  `time` time DEFAULT NULL,
  `disabled` tinyint(1) NOT NULL DEFAULT 0,
  `route_schedule_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `trips`
--

INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17033, 1, 2, '2025-10-17', '11:30:00', 0, 4);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17034, 1, 4, '2025-10-17', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17035, 1, 4, '2025-10-17', '07:00:00', 0, 2);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17036, 1, 4, '2025-10-17', '09:00:00', 0, 3);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17038, 1, 4, '2025-10-17', '13:30:00', 0, 5);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17039, 1, 4, '2025-10-17', '15:30:00', 0, 6);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17040, 1, 1, '2025-10-17', '17:00:00', 0, 7);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17041, 1, 1, '2025-10-17', '19:00:00', 0, 8);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17042, 2, 1, '2025-10-17', '08:00:00', 0, 9);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17043, 3, 1, '2025-10-17', '08:00:00', 0, 10);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17044, 4, 4, '2025-10-17', '21:00:00', 0, 11);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17045, 5, 1, '2025-10-17', '16:00:00', 0, 12);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17046, 6, 4, '2025-10-17', '14:00:00', 0, 13);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17047, 7, 1, '2025-10-17', '07:00:00', 0, 14);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17048, 7, 4, '2025-10-17', '10:00:00', 0, 15);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17049, 7, 4, '2025-10-17', '12:00:00', 0, 16);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17050, 7, 1, '2025-10-17', '13:00:00', 0, 17);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17051, 7, 4, '2025-10-17', '14:00:00', 0, 18);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17052, 7, 1, '2025-10-17', '15:00:00', 0, 19);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17053, 7, 4, '2025-10-17', '17:00:00', 0, 20);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17054, 7, 4, '2025-10-17', '19:00:00', 0, 21);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17055, 8, 1, '2025-10-17', '16:00:00', 0, 22);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17056, 9, 1, '2025-10-17', '07:00:00', 0, 23);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17057, 10, 1, '2025-10-17', '11:00:00', 0, 24);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17058, 1, 4, '2025-10-18', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17059, 1, 4, '2025-10-18', '07:00:00', 0, 2);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17060, 1, 4, '2025-10-18', '09:00:00', 0, 3);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17061, 1, 1, '2025-10-18', '11:30:00', 0, 4);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17062, 1, 4, '2025-10-18', '13:30:00', 0, 5);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17063, 1, 4, '2025-10-18', '15:30:00', 0, 6);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17064, 1, 1, '2025-10-18', '17:00:00', 0, 7);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17065, 1, 1, '2025-10-18', '19:00:00', 0, 8);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17066, 2, 1, '2025-10-18', '08:00:00', 0, 9);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17067, 3, 1, '2025-10-18', '08:00:00', 0, 10);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17068, 4, 4, '2025-10-18', '21:00:00', 0, 11);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17069, 5, 1, '2025-10-18', '16:00:00', 0, 12);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17070, 6, 4, '2025-10-18', '14:00:00', 0, 13);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17071, 7, 1, '2025-10-18', '07:00:00', 0, 14);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17072, 7, 4, '2025-10-18', '10:00:00', 0, 15);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17073, 7, 4, '2025-10-18', '12:00:00', 0, 16);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17074, 7, 1, '2025-10-18', '13:00:00', 0, 17);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17075, 7, 4, '2025-10-18', '14:00:00', 0, 18);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17076, 7, 1, '2025-10-18', '15:00:00', 0, 19);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17077, 7, 4, '2025-10-18', '17:00:00', 0, 20);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17078, 7, 4, '2025-10-18', '19:00:00', 0, 21);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17079, 8, 1, '2025-10-18', '16:00:00', 0, 22);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17080, 9, 1, '2025-10-18', '07:00:00', 0, 23);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17081, 10, 1, '2025-10-18', '11:00:00', 0, 24);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17082, 1, 4, '2025-10-19', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17083, 1, 4, '2025-10-19', '07:00:00', 0, 2);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17084, 1, 4, '2025-10-19', '09:00:00', 0, 3);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17085, 1, 1, '2025-10-19', '11:30:00', 0, 4);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17086, 1, 4, '2025-10-19', '13:30:00', 0, 5);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17087, 1, 4, '2025-10-19', '15:30:00', 0, 6);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17088, 1, 1, '2025-10-19', '17:00:00', 0, 7);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17089, 1, 1, '2025-10-19', '19:00:00', 0, 8);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17090, 2, 1, '2025-10-19', '08:00:00', 0, 9);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17091, 3, 1, '2025-10-19', '08:00:00', 0, 10);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17092, 4, 4, '2025-10-19', '21:00:00', 0, 11);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17093, 5, 1, '2025-10-19', '16:00:00', 0, 12);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17094, 6, 4, '2025-10-19', '14:00:00', 0, 13);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17095, 7, 1, '2025-10-19', '07:00:00', 0, 14);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17096, 7, 4, '2025-10-19', '10:00:00', 0, 15);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17097, 7, 4, '2025-10-19', '12:00:00', 0, 16);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17098, 7, 1, '2025-10-19', '13:00:00', 0, 17);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17099, 7, 4, '2025-10-19', '14:00:00', 0, 18);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17100, 7, 1, '2025-10-19', '15:00:00', 0, 19);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17101, 7, 4, '2025-10-19', '17:00:00', 0, 20);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17102, 7, 4, '2025-10-19', '19:00:00', 0, 21);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17103, 8, 1, '2025-10-19', '16:00:00', 0, 22);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17104, 9, 1, '2025-10-19', '07:00:00', 0, 23);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17105, 10, 1, '2025-10-19', '11:00:00', 0, 24);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17106, 1, 4, '2025-10-20', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17107, 1, 4, '2025-10-20', '07:00:00', 0, 2);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17108, 1, 4, '2025-10-20', '09:00:00', 0, 3);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17109, 1, 1, '2025-10-20', '11:30:00', 0, 4);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17110, 1, 4, '2025-10-20', '13:30:00', 0, 5);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17111, 1, 4, '2025-10-20', '15:30:00', 0, 6);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17112, 1, 1, '2025-10-20', '17:00:00', 0, 7);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17113, 1, 1, '2025-10-20', '19:00:00', 0, 8);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17114, 2, 1, '2025-10-20', '08:00:00', 0, 9);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17115, 3, 1, '2025-10-20', '08:00:00', 0, 10);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17116, 4, 4, '2025-10-20', '21:00:00', 0, 11);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17117, 5, 1, '2025-10-20', '16:00:00', 0, 12);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17118, 6, 4, '2025-10-20', '14:00:00', 0, 13);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17119, 7, 1, '2025-10-20', '07:00:00', 0, 14);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17120, 7, 4, '2025-10-20', '10:00:00', 0, 15);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17121, 7, 4, '2025-10-20', '12:00:00', 0, 16);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17122, 7, 1, '2025-10-20', '13:00:00', 0, 17);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17123, 7, 4, '2025-10-20', '14:00:00', 0, 18);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17124, 7, 1, '2025-10-20', '15:00:00', 0, 19);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17125, 7, 4, '2025-10-20', '17:00:00', 0, 20);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17126, 7, 4, '2025-10-20', '19:00:00', 0, 21);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17127, 8, 1, '2025-10-20', '16:00:00', 0, 22);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17128, 9, 1, '2025-10-20', '07:00:00', 0, 23);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17129, 10, 1, '2025-10-20', '11:00:00', 0, 24);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17130, 1, 4, '2025-10-21', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17131, 1, 4, '2025-10-21', '07:00:00', 0, 2);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17132, 1, 4, '2025-10-21', '09:00:00', 0, 3);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17133, 1, 1, '2025-10-21', '11:30:00', 0, 4);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17134, 1, 4, '2025-10-21', '13:30:00', 0, 5);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17135, 1, 4, '2025-10-21', '15:30:00', 0, 6);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17136, 1, 1, '2025-10-21', '17:00:00', 0, 7);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17137, 1, 1, '2025-10-21', '19:00:00', 0, 8);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17138, 2, 1, '2025-10-21', '08:00:00', 0, 9);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17139, 3, 1, '2025-10-21', '08:00:00', 0, 10);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17140, 4, 4, '2025-10-21', '21:00:00', 0, 11);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17142, 5, 1, '2025-10-21', '16:00:00', 0, 12);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17145, 6, 4, '2025-10-21', '14:00:00', 0, 13);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17148, 7, 1, '2025-10-21', '07:00:00', 0, 14);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17151, 7, 4, '2025-10-21', '10:00:00', 0, 15);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17154, 7, 4, '2025-10-21', '12:00:00', 0, 16);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17158, 7, 1, '2025-10-21', '13:00:00', 0, 17);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17161, 7, 4, '2025-10-21', '14:00:00', 0, 18);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17163, 7, 1, '2025-10-21', '15:00:00', 0, 19);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17167, 7, 4, '2025-10-21', '17:00:00', 0, 20);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17169, 7, 4, '2025-10-21', '19:00:00', 0, 21);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17172, 8, 1, '2025-10-21', '16:00:00', 0, 22);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17175, 9, 1, '2025-10-21', '07:00:00', 0, 23);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17178, 10, 1, '2025-10-21', '11:00:00', 0, 24);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17181, 1, 4, '2025-10-22', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17184, 1, 4, '2025-10-22', '07:00:00', 0, 2);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17187, 1, 4, '2025-10-22', '09:00:00', 0, 3);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17189, 1, 1, '2025-10-22', '11:30:00', 0, 4);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17193, 1, 4, '2025-10-22', '13:30:00', 0, 5);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17195, 1, 4, '2025-10-22', '15:30:00', 0, 6);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17198, 1, 1, '2025-10-22', '17:00:00', 0, 7);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17201, 1, 1, '2025-10-22', '19:00:00', 0, 8);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17204, 2, 1, '2025-10-22', '08:00:00', 0, 9);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17207, 3, 1, '2025-10-22', '08:00:00', 0, 10);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17210, 4, 4, '2025-10-22', '21:00:00', 0, 11);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17213, 5, 1, '2025-10-22', '16:00:00', 0, 12);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17216, 6, 4, '2025-10-22', '14:00:00', 0, 13);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17219, 7, 1, '2025-10-22', '07:00:00', 0, 14);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17221, 7, 4, '2025-10-22', '10:00:00', 0, 15);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17225, 7, 4, '2025-10-22', '12:00:00', 0, 16);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17228, 7, 1, '2025-10-22', '13:00:00', 0, 17);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17231, 7, 4, '2025-10-22', '14:00:00', 0, 18);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17234, 7, 1, '2025-10-22', '15:00:00', 0, 19);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17237, 7, 4, '2025-10-22', '17:00:00', 0, 20);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17240, 7, 4, '2025-10-22', '19:00:00', 0, 21);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17243, 8, 1, '2025-10-22', '16:00:00', 0, 22);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17246, 9, 1, '2025-10-22', '07:00:00', 0, 23);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17249, 10, 1, '2025-10-22', '11:00:00', 0, 24);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17252, 1, 4, '2025-10-23', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17255, 1, 4, '2025-10-23', '07:00:00', 0, 2);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17258, 1, 4, '2025-10-23', '09:00:00', 0, 3);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17261, 1, 1, '2025-10-23', '11:30:00', 0, 4);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17264, 1, 4, '2025-10-23', '13:30:00', 0, 5);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17267, 1, 4, '2025-10-23', '15:30:00', 0, 6);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17270, 1, 1, '2025-10-23', '17:00:00', 0, 7);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17273, 1, 1, '2025-10-23', '19:00:00', 0, 8);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17277, 2, 1, '2025-10-23', '08:00:00', 0, 9);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17279, 3, 1, '2025-10-23', '08:00:00', 0, 10);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17283, 4, 4, '2025-10-23', '21:00:00', 0, 11);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17285, 5, 1, '2025-10-23', '16:00:00', 0, 12);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17288, 6, 4, '2025-10-23', '14:00:00', 0, 13);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17291, 7, 1, '2025-10-23', '07:00:00', 0, 14);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17294, 7, 4, '2025-10-23', '10:00:00', 0, 15);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17297, 7, 4, '2025-10-23', '12:00:00', 0, 16);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17300, 7, 1, '2025-10-23', '13:00:00', 0, 17);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17303, 7, 4, '2025-10-23', '14:00:00', 0, 18);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17306, 7, 1, '2025-10-23', '15:00:00', 0, 19);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17309, 7, 4, '2025-10-23', '17:00:00', 0, 20);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17312, 7, 4, '2025-10-23', '19:00:00', 0, 21);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17315, 8, 1, '2025-10-23', '16:00:00', 0, 22);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17318, 9, 1, '2025-10-23', '07:00:00', 0, 23);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(17321, 10, 1, '2025-10-23', '11:00:00', 0, 24);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(27117, 1, 1, '2025-10-17', '11:30:00', 0, 4);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(28794, 1, 4, '2024-10-17', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(28795, 1, 4, '2024-10-18', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(28796, 1, 4, '2024-10-01', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32781, 1, 4, '2025-10-24', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32783, 1, 4, '2025-10-24', '07:00:00', 0, 2);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32785, 1, 4, '2025-10-24', '09:00:00', 0, 3);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32787, 1, 1, '2025-10-24', '11:30:00', 0, 4);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32789, 1, 4, '2025-10-24', '13:30:00', 0, 5);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32791, 1, 4, '2025-10-24', '15:30:00', 0, 6);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32793, 1, 1, '2025-10-24', '17:00:00', 0, 7);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32795, 1, 1, '2025-10-24', '19:00:00', 0, 8);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32797, 2, 1, '2025-10-24', '08:00:00', 0, 9);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32799, 3, 1, '2025-10-24', '08:00:00', 0, 10);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32801, 4, 4, '2025-10-24', '21:00:00', 0, 11);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32803, 5, 1, '2025-10-24', '16:00:00', 0, 12);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32805, 6, 4, '2025-10-24', '14:00:00', 0, 13);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32807, 7, 1, '2025-10-24', '07:00:00', 0, 14);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32809, 7, 4, '2025-10-24', '10:00:00', 0, 15);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32811, 7, 4, '2025-10-24', '12:00:00', 0, 16);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32813, 7, 1, '2025-10-24', '13:00:00', 0, 17);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32815, 7, 4, '2025-10-24', '14:00:00', 0, 18);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32817, 7, 1, '2025-10-24', '15:00:00', 0, 19);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32819, 7, 4, '2025-10-24', '17:00:00', 0, 20);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32821, 7, 4, '2025-10-24', '19:00:00', 0, 21);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32823, 8, 1, '2025-10-24', '16:00:00', 0, 22);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32825, 9, 1, '2025-10-24', '07:00:00', 0, 23);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(32827, 10, 1, '2025-10-24', '11:00:00', 0, 24);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41180, 1, 4, '2025-10-25', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41183, 1, 4, '2025-10-25', '07:00:00', 0, 2);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41185, 1, 4, '2025-10-25', '09:00:00', 0, 3);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41187, 1, 1, '2025-10-25', '11:30:00', 0, 4);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41189, 1, 4, '2025-10-25', '13:30:00', 0, 5);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41191, 1, 4, '2025-10-25', '15:30:00', 0, 6);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41193, 1, 1, '2025-10-25', '17:00:00', 0, 7);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41195, 1, 1, '2025-10-25', '19:00:00', 0, 8);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41197, 2, 1, '2025-10-25', '08:00:00', 0, 9);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41199, 3, 1, '2025-10-25', '08:00:00', 0, 10);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41201, 4, 4, '2025-10-25', '21:00:00', 0, 11);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41203, 5, 1, '2025-10-25', '16:00:00', 0, 12);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41205, 6, 4, '2025-10-25', '14:00:00', 0, 13);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41207, 7, 1, '2025-10-25', '07:00:00', 0, 14);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41209, 7, 4, '2025-10-25', '10:00:00', 0, 15);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41211, 7, 4, '2025-10-25', '12:00:00', 0, 16);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41213, 7, 1, '2025-10-25', '13:00:00', 0, 17);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41215, 7, 4, '2025-10-25', '14:00:00', 0, 18);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41217, 7, 1, '2025-10-25', '15:00:00', 0, 19);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41219, 7, 4, '2025-10-25', '17:00:00', 0, 20);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41221, 7, 4, '2025-10-25', '19:00:00', 0, 21);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41223, 8, 1, '2025-10-25', '16:00:00', 0, 22);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41225, 9, 1, '2025-10-25', '07:00:00', 0, 23);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(41227, 10, 1, '2025-10-25', '11:00:00', 0, 24);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47521, 1, 4, '2025-10-26', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47524, 1, 4, '2025-10-26', '07:00:00', 0, 2);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47526, 1, 4, '2025-10-26', '09:00:00', 0, 3);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47528, 1, 1, '2025-10-26', '11:30:00', 0, 4);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47530, 1, 4, '2025-10-26', '13:30:00', 0, 5);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47532, 1, 4, '2025-10-26', '15:30:00', 0, 6);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47534, 1, 1, '2025-10-26', '17:00:00', 0, 7);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47536, 1, 1, '2025-10-26', '19:00:00', 0, 8);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47538, 2, 1, '2025-10-26', '08:00:00', 0, 9);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47540, 3, 1, '2025-10-26', '08:00:00', 0, 10);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47542, 4, 4, '2025-10-26', '21:00:00', 0, 11);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47544, 5, 1, '2025-10-26', '16:00:00', 0, 12);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47546, 6, 4, '2025-10-26', '14:00:00', 0, 13);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47548, 7, 1, '2025-10-26', '07:00:00', 0, 14);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47550, 7, 4, '2025-10-26', '10:00:00', 0, 15);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47552, 7, 4, '2025-10-26', '12:00:00', 0, 16);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47554, 7, 1, '2025-10-26', '13:00:00', 0, 17);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47556, 7, 4, '2025-10-26', '14:00:00', 0, 18);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47558, 7, 1, '2025-10-26', '15:00:00', 0, 19);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47560, 7, 4, '2025-10-26', '17:00:00', 0, 20);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47562, 7, 4, '2025-10-26', '19:00:00', 0, 21);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47564, 8, 1, '2025-10-26', '16:00:00', 0, 22);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47566, 9, 1, '2025-10-26', '07:00:00', 0, 23);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47568, 10, 1, '2025-10-26', '11:00:00', 0, 24);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47714, 1, 4, '2025-10-27', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47715, 1, 4, '2025-10-27', '07:00:00', 0, 2);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47716, 1, 4, '2025-10-27', '09:00:00', 0, 3);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47717, 1, 1, '2025-10-27', '11:30:00', 0, 4);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47719, 1, 4, '2025-10-27', '13:30:00', 0, 5);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47721, 1, 4, '2025-10-27', '15:30:00', 0, 6);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47725, 1, 1, '2025-10-27', '17:00:00', 0, 7);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47729, 1, 1, '2025-10-27', '19:00:00', 0, 8);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47732, 2, 1, '2025-10-27', '08:00:00', 0, 9);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47735, 3, 1, '2025-10-27', '08:00:00', 0, 10);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47738, 4, 4, '2025-10-27', '21:00:00', 0, 11);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47741, 5, 1, '2025-10-27', '16:00:00', 0, 12);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47744, 6, 4, '2025-10-27', '14:00:00', 0, 13);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47747, 7, 1, '2025-10-27', '07:00:00', 0, 14);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47750, 7, 4, '2025-10-27', '10:00:00', 0, 15);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47753, 7, 4, '2025-10-27', '12:00:00', 0, 16);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47755, 7, 1, '2025-10-27', '13:00:00', 0, 17);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47758, 7, 4, '2025-10-27', '14:00:00', 0, 18);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47762, 7, 1, '2025-10-27', '15:00:00', 0, 19);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47765, 7, 4, '2025-10-27', '17:00:00', 0, 20);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47767, 7, 4, '2025-10-27', '19:00:00', 0, 21);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47769, 8, 1, '2025-10-27', '16:00:00', 0, 22);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47772, 9, 1, '2025-10-27', '07:00:00', 0, 23);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(47775, 10, 1, '2025-10-27', '11:00:00', 0, 24);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49536, 1, 4, '2025-10-28', '06:00:00', 0, 1);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49540, 1, 4, '2025-10-28', '07:00:00', 0, 2);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49542, 1, 4, '2025-10-28', '09:00:00', 0, 3);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49544, 1, 1, '2025-10-28', '11:30:00', 0, 4);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49546, 1, 4, '2025-10-28', '13:30:00', 0, 5);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49548, 1, 4, '2025-10-28', '15:30:00', 0, 6);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49550, 1, 1, '2025-10-28', '17:00:00', 0, 7);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49552, 1, 1, '2025-10-28', '19:00:00', 0, 8);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49554, 2, 1, '2025-10-28', '08:00:00', 0, 9);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49556, 3, 1, '2025-10-28', '08:00:00', 0, 10);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49558, 4, 4, '2025-10-28', '21:00:00', 0, 11);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49560, 5, 1, '2025-10-28', '16:00:00', 0, 12);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49562, 6, 4, '2025-10-28', '14:00:00', 0, 13);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49564, 7, 1, '2025-10-28', '07:00:00', 0, 14);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49566, 7, 4, '2025-10-28', '10:00:00', 0, 15);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49568, 7, 4, '2025-10-28', '12:00:00', 0, 16);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49570, 7, 1, '2025-10-28', '13:00:00', 0, 17);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49572, 7, 4, '2025-10-28', '14:00:00', 0, 18);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49574, 7, 1, '2025-10-28', '15:00:00', 0, 19);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49576, 7, 4, '2025-10-28', '17:00:00', 0, 20);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49578, 7, 4, '2025-10-28', '19:00:00', 0, 21);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49580, 8, 1, '2025-10-28', '16:00:00', 0, 22);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49582, 9, 1, '2025-10-28', '07:00:00', 0, 23);
INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES(49584, 10, 1, '2025-10-28', '11:00:00', 0, 24);

--
-- Triggers `trips`
--
DELIMITER $$
CREATE TRIGGER `trg_trips_ai_snapshot` AFTER INSERT ON `trips` FOR EACH ROW BEGIN
  CALL sp_fill_trip_stations(NEW.id);
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `trip_stations`
--

CREATE TABLE `trip_stations` (
  `trip_id` int(11) NOT NULL,
  `station_id` int(11) NOT NULL,
  `sequence` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `trip_stations`
--

INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17033, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17033, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17033, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17033, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17033, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17034, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17034, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17034, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17034, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17034, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17035, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17035, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17035, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17035, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17035, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17036, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17036, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17036, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17036, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17036, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17038, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17038, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17038, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17038, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17038, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17039, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17039, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17039, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17039, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17039, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17040, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17040, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17040, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17040, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17040, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17041, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17041, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17041, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17041, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17041, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17042, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17042, 10, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17042, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17043, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17043, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17043, 4, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17044, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17044, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17044, 3, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17045, 4, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17045, 15, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17045, 1, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17045, 8, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17046, 3, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17046, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17046, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17047, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17047, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17047, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17048, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17048, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17048, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17049, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17049, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17049, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17050, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17050, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17050, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17051, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17051, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17051, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17052, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17052, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17052, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17053, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17053, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17053, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17054, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17054, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17054, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17055, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17055, 8, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17056, 9, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17056, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17056, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17057, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17057, 7, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17057, 9, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17058, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17058, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17058, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17058, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17058, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17059, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17059, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17059, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17059, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17059, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17060, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17060, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17060, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17060, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17060, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17061, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17061, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17061, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17061, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17061, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17062, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17062, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17062, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17062, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17062, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17063, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17063, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17063, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17063, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17063, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17064, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17064, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17064, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17064, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17064, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17065, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17065, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17065, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17065, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17065, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17066, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17066, 10, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17066, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17067, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17067, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17067, 4, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17068, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17068, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17068, 3, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17069, 4, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17069, 15, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17069, 1, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17069, 8, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17070, 3, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17070, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17070, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17071, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17071, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17071, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17072, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17072, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17072, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17073, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17073, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17073, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17074, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17074, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17074, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17075, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17075, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17075, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17076, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17076, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17076, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17077, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17077, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17077, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17078, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17078, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17078, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17079, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17079, 8, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17080, 9, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17080, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17080, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17081, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17081, 7, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17081, 9, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17082, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17082, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17082, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17082, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17082, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17083, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17083, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17083, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17083, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17083, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17084, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17084, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17084, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17084, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17084, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17085, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17085, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17085, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17085, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17085, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17086, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17086, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17086, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17086, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17086, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17087, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17087, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17087, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17087, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17087, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17088, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17088, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17088, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17088, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17088, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17089, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17089, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17089, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17089, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17089, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17090, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17090, 10, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17090, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17091, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17091, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17091, 4, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17092, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17092, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17092, 3, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17093, 4, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17093, 15, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17093, 1, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17093, 8, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17094, 3, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17094, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17094, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17095, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17095, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17095, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17096, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17096, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17096, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17097, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17097, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17097, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17098, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17098, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17098, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17099, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17099, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17099, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17100, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17100, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17100, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17101, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17101, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17101, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17102, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17102, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17102, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17103, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17103, 8, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17104, 9, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17104, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17104, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17105, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17105, 7, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17105, 9, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17106, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17106, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17106, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17106, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17106, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17107, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17107, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17107, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17107, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17107, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17108, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17108, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17108, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17108, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17108, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17109, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17109, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17109, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17109, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17109, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17110, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17110, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17110, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17110, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17110, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17111, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17111, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17111, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17111, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17111, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17112, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17112, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17112, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17112, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17112, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17113, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17113, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17113, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17113, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17113, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17114, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17114, 10, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17114, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17115, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17115, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17115, 4, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17116, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17116, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17116, 3, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17117, 4, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17117, 15, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17117, 1, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17117, 8, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17118, 3, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17118, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17118, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17119, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17119, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17119, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17120, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17120, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17120, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17121, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17121, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17121, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17122, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17122, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17122, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17123, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17123, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17123, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17124, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17124, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17124, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17125, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17125, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17125, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17126, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17126, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17126, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17127, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17127, 8, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17128, 9, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17128, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17128, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17129, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17129, 7, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17129, 9, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17130, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17130, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17130, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17130, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17130, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17131, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17131, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17131, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17131, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17131, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17132, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17132, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17132, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17132, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17132, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17133, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17133, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17133, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17133, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17133, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17134, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17134, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17134, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17134, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17134, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17135, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17135, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17135, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17135, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17135, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17136, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17136, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17136, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17136, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17136, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17137, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17137, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17137, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17137, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17137, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17138, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17138, 10, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17138, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17139, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17139, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17139, 4, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17140, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17140, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17140, 3, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17142, 4, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17142, 15, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17142, 1, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17142, 8, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17145, 3, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17145, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17145, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17148, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17148, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17148, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17151, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17151, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17151, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17154, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17154, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17154, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17158, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17158, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17158, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17161, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17161, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17161, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17163, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17163, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17163, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17167, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17167, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17167, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17169, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17169, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17169, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17172, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17172, 8, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17175, 9, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17175, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17175, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17178, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17178, 7, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17178, 9, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17181, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17181, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17181, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17181, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17181, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17184, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17184, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17184, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17184, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17184, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17187, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17187, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17187, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17187, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17187, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17189, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17189, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17189, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17189, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17189, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17193, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17193, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17193, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17193, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17193, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17195, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17195, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17195, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17195, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17195, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17198, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17198, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17198, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17198, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17198, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17201, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17201, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17201, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17201, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17201, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17204, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17204, 10, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17204, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17207, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17207, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17207, 4, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17210, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17210, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17210, 3, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17213, 4, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17213, 15, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17213, 1, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17213, 8, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17216, 3, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17216, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17216, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17219, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17219, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17219, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17221, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17221, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17221, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17225, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17225, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17225, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17228, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17228, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17228, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17231, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17231, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17231, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17234, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17234, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17234, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17237, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17237, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17237, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17240, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17240, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17240, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17243, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17243, 8, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17246, 9, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17246, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17246, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17249, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17249, 7, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17249, 9, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17252, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17252, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17252, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17252, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17252, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17255, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17255, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17255, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17255, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17255, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17258, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17258, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17258, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17258, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17258, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17261, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17261, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17261, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17261, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17261, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17264, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17264, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17264, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17264, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17264, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17267, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17267, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17267, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17267, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17267, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17270, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17270, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17270, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17270, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17270, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17273, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17273, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17273, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17273, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17273, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17277, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17277, 10, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17277, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17279, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17279, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17279, 4, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17283, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17283, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17283, 3, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17285, 4, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17285, 15, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17285, 1, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17285, 8, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17288, 3, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17288, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17288, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17291, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17291, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17291, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17294, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17294, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17294, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17297, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17297, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17297, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17300, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17300, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17300, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17303, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17303, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17303, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17306, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17306, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17306, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17309, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17309, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17309, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17312, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17312, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17312, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17315, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17315, 8, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17318, 9, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17318, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17318, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17321, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17321, 7, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(17321, 9, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(27117, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(27117, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(27117, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(27117, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(27117, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28794, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28794, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28794, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28794, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28794, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28795, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28795, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28795, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28795, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28795, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28796, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28796, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28796, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28796, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(28796, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32781, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32781, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32781, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32781, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32781, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32783, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32783, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32783, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32783, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32783, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32785, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32785, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32785, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32785, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32785, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32787, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32787, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32787, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32787, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32787, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32789, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32789, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32789, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32789, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32789, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32791, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32791, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32791, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32791, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32791, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32793, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32793, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32793, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32793, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32793, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32795, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32795, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32795, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32795, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32795, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32797, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32797, 10, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32797, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32799, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32799, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32799, 4, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32801, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32801, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32801, 3, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32803, 4, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32803, 15, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32803, 1, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32803, 8, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32805, 3, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32805, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32805, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32807, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32807, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32807, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32809, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32809, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32809, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32811, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32811, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32811, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32813, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32813, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32813, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32815, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32815, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32815, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32817, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32817, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32817, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32819, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32819, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32819, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32821, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32821, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32821, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32823, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32823, 8, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32825, 9, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32825, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32825, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32827, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32827, 7, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(32827, 9, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41180, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41180, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41180, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41180, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41180, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41183, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41183, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41183, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41183, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41183, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41185, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41185, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41185, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41185, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41185, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41187, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41187, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41187, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41187, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41187, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41189, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41189, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41189, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41189, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41189, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41191, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41191, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41191, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41191, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41191, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41193, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41193, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41193, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41193, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41193, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41195, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41195, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41195, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41195, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41195, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41197, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41197, 10, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41197, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41199, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41199, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41199, 4, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41201, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41201, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41201, 3, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41203, 4, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41203, 15, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41203, 1, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41203, 8, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41205, 3, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41205, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41205, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41207, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41207, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41207, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41209, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41209, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41209, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41211, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41211, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41211, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41213, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41213, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41213, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41215, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41215, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41215, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41217, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41217, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41217, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41219, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41219, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41219, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41221, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41221, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41221, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41223, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41223, 8, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41225, 9, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41225, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41225, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41227, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41227, 7, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(41227, 9, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47521, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47521, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47521, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47521, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47521, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47524, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47524, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47524, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47524, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47524, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47526, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47526, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47526, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47526, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47526, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47528, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47528, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47528, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47528, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47528, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47530, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47530, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47530, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47530, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47530, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47532, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47532, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47532, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47532, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47532, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47534, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47534, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47534, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47534, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47534, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47536, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47536, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47536, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47536, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47536, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47538, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47538, 10, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47538, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47540, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47540, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47540, 4, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47542, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47542, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47542, 3, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47544, 4, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47544, 15, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47544, 1, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47544, 8, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47546, 3, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47546, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47546, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47548, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47548, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47548, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47550, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47550, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47550, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47552, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47552, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47552, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47554, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47554, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47554, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47556, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47556, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47556, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47558, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47558, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47558, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47560, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47560, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47560, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47562, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47562, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47562, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47564, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47564, 8, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47566, 9, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47566, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47566, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47568, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47568, 7, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47568, 9, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47714, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47714, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47714, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47714, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47714, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47715, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47715, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47715, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47715, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47715, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47716, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47716, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47716, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47716, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47716, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47717, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47717, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47717, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47717, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47717, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47719, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47719, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47719, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47719, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47719, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47721, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47721, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47721, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47721, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47721, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47725, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47725, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47725, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47725, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47725, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47729, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47729, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47729, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47729, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47729, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47732, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47732, 10, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47732, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47735, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47735, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47735, 4, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47738, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47738, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47738, 3, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47741, 4, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47741, 15, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47741, 1, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47741, 8, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47744, 3, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47744, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47744, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47747, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47747, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47747, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47750, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47750, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47750, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47753, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47753, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47753, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47755, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47755, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47755, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47758, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47758, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47758, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47762, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47762, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47762, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47765, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47765, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47765, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47767, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47767, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47767, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47769, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47769, 8, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47772, 9, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47772, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47772, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47775, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47775, 7, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(47775, 9, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49536, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49536, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49536, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49536, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49536, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49540, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49540, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49540, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49540, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49540, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49542, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49542, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49542, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49542, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49542, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49544, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49544, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49544, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49544, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49544, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49546, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49546, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49546, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49546, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49546, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49548, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49548, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49548, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49548, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49548, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49550, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49550, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49550, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49550, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49550, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49552, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49552, 14, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49552, 5, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49552, 11, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49552, 6, 5);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49554, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49554, 10, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49554, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49556, 7, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49556, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49556, 4, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49558, 8, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49558, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49558, 3, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49560, 4, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49560, 15, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49560, 1, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49560, 8, 4);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49562, 3, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49562, 2, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49562, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49564, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49564, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49564, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49566, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49566, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49566, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49568, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49568, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49568, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49570, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49570, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49570, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49572, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49572, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49572, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49574, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49574, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49574, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49576, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49576, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49576, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49578, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49578, 11, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49578, 7, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49580, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49580, 8, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49582, 9, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49582, 5, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49582, 6, 3);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49584, 6, 1);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49584, 7, 2);
INSERT INTO `trip_stations` (`trip_id`, `station_id`, `sequence`) VALUES(49584, 9, 3);

-- --------------------------------------------------------

--
-- Table structure for table `trip_vehicles`
--

CREATE TABLE `trip_vehicles` (
  `id` int(11) NOT NULL,
  `trip_id` int(11) DEFAULT NULL,
  `vehicle_id` int(11) DEFAULT NULL,
  `is_primary` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `trip_vehicles`
--

INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(1, 1, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(3, 2, 5, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(4, 3, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(5, 4, 3, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(6, 5, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(7, 6, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(8, 7, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(9, 8, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(10, 9, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11, 10, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(12, 11, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13, 12, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14, 13, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(15, 14, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16, 15, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17, 16, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(18, 17, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(19, 18, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(20, 19, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(21, 20, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(22, 21, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(23, 22, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(24, 23, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(25, 24, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(26, 25, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(27, 26, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(28, 27, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(29, 28, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(30, 29, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(31, 30, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32, 31, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(33, 32, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(34, 33, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(35, 34, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(36, 35, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(37, 36, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(38, 37, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(39, 38, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(40, 39, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41, 40, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(42, 41, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(43, 42, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(44, 43, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(45, 44, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(46, 45, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47, 46, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(48, 47, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49, 48, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(50, 49, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(51, 50, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(52, 51, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(53, 52, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(54, 53, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(55, 54, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(56, 55, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(57, 56, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(58, 57, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(59, 58, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(60, 59, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(61, 60, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(62, 61, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(63, 62, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(64, 63, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(65, 64, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(66, 65, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(67, 66, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(68, 67, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(69, 68, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(70, 69, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(71, 70, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(72, 71, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(73, 72, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(74, 73, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(75, 74, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(76, 75, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(77, 76, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(78, 77, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(79, 78, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(80, 79, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(81, 80, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(82, 81, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(83, 82, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(84, 83, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(85, 84, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(86, 85, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(87, 86, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(88, 87, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(89, 88, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(90, 89, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(91, 90, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(92, 91, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(93, 92, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(94, 93, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(95, 94, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(96, 95, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(97, 96, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(98, 97, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(99, 98, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(100, 99, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(101, 100, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(102, 101, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(103, 102, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(104, 103, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(105, 104, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(106, 105, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(107, 106, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(108, 107, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(109, 108, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(110, 109, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(111, 110, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(112, 111, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(113, 112, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(114, 113, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(115, 114, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(116, 115, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(117, 116, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(118, 117, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(119, 118, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(120, 119, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(121, 120, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(122, 121, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(123, 122, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(124, 123, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(125, 124, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(126, 125, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(127, 126, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(128, 127, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(129, 128, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(130, 129, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(131, 130, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(132, 131, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(133, 132, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(134, 133, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(135, 134, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(136, 135, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(137, 136, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(138, 137, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(139, 138, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(140, 139, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(141, 140, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(142, 141, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(143, 142, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(144, 143, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(145, 144, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(146, 145, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(147, 146, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(148, 147, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(149, 148, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(150, 149, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(151, 150, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(152, 151, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(153, 152, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(154, 153, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(155, 154, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(156, 155, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(157, 156, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(158, 157, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(159, 158, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(160, 159, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(161, 160, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(162, 161, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(163, 162, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(164, 163, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(165, 164, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(166, 165, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(167, 166, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(168, 167, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(169, 168, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(10922, 10921, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(10923, 10922, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(10924, 10923, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(10925, 10924, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(10926, 10925, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11142, 11138, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11145, 11142, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11148, 11144, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11150, 11147, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11152, 11149, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11154, 11151, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11157, 11154, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11159, 11156, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11162, 11159, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11164, 11161, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11167, 11163, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11169, 11166, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11172, 11168, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11174, 11171, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11177, 11173, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11179, 11176, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11181, 11178, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11184, 11181, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11187, 11183, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11189, 11185, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11191, 11188, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11194, 11190, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11197, 11193, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11199, 11196, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11266, 11262, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11267, 11263, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11604, 11600, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11605, 11601, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11606, 11602, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11607, 11603, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11608, 11604, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(11609, 11605, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13290, 13286, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13291, 13287, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13292, 13288, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13293, 13289, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13294, 13290, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13295, 13291, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13296, 13292, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13297, 13293, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13298, 13294, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13299, 13295, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13300, 13296, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13301, 13297, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13302, 13298, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13303, 13299, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13304, 13300, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13305, 13301, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13306, 13302, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13307, 13303, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13308, 13304, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13309, 13305, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13310, 13306, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13311, 13307, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13312, 13308, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13313, 13309, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13314, 13310, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13315, 13311, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13316, 13312, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13317, 13313, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13318, 13314, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13319, 13315, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13320, 13316, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13321, 13317, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13322, 13318, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13323, 13319, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13324, 13320, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13325, 13321, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13326, 13322, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13327, 13323, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13328, 13324, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13329, 13325, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13330, 13326, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13331, 13327, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13332, 13328, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13333, 13329, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13334, 13330, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13335, 13331, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(13336, 13332, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14251, 14247, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14253, 14249, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14255, 14251, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14257, 14253, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14259, 14255, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14261, 14257, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14263, 14259, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14265, 14261, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14267, 14263, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14269, 14265, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14271, 14267, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14273, 14269, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14275, 14271, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14277, 14273, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14279, 14275, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14281, 14277, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14283, 14279, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14285, 14281, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14287, 14283, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14289, 14285, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14291, 14287, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14293, 14289, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14295, 14291, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14297, 14293, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14299, 14295, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14301, 14297, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14303, 14299, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14305, 14301, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14307, 14303, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14309, 14305, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14311, 14307, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14313, 14309, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14315, 14311, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14317, 14313, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14319, 14315, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14321, 14317, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14323, 14319, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14325, 14321, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14327, 14323, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14329, 14325, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14331, 14327, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14333, 14329, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14335, 14331, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14337, 14333, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14339, 14335, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14341, 14337, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14343, 14339, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14345, 14341, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14346, 14342, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14347, 14343, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14349, 14345, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14350, 14346, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14352, 14348, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14353, 14349, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14354, 14350, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14355, 14351, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14356, 14352, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14357, 14353, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14358, 14354, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14359, 14355, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14360, 14356, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14361, 14357, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14362, 14358, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14363, 14359, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14364, 14360, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14365, 14361, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14366, 14362, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14367, 14363, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14368, 14364, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14369, 14365, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14370, 14366, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14371, 14367, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14372, 14369, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14375, 14371, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14378, 14373, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14381, 14377, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14384, 14379, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14387, 14383, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14390, 14386, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14393, 14389, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14396, 14392, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14399, 14395, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14402, 14398, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14405, 14401, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14408, 14404, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14411, 14407, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14415, 14410, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14417, 14413, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14420, 14416, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14424, 14419, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14426, 14422, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14429, 14425, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14432, 14428, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14435, 14431, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14438, 14433, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14441, 14436, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14444, 14440, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14446, 14442, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14448, 14444, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14450, 14446, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14452, 14448, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14454, 14450, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14456, 14452, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14458, 14454, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14460, 14456, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14462, 14458, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14464, 14460, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14466, 14462, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14468, 14464, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14470, 14466, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14472, 14468, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14474, 14470, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14476, 14472, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14478, 14474, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14480, 14476, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14482, 14478, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14484, 14480, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14486, 14482, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14488, 14484, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14490, 14486, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14492, 14488, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14494, 14490, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14496, 14492, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14498, 14494, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14500, 14496, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14502, 14498, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14504, 14500, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14506, 14502, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14508, 14504, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14510, 14506, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14512, 14508, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14514, 14510, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14516, 14512, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14518, 14514, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14520, 14516, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14522, 14518, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14524, 14520, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14526, 14522, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14528, 14524, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14530, 14526, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14532, 14528, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14534, 14530, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14536, 14532, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14538, 14534, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14540, 14536, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14542, 14538, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14544, 14540, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14546, 14542, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14548, 14544, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14550, 14546, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14552, 14548, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14554, 14550, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14556, 14552, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14558, 14554, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14560, 14556, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14562, 14558, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14564, 14560, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14566, 14562, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14568, 14564, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14570, 14566, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14572, 14568, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14574, 14570, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14576, 14572, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14578, 14574, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14580, 14576, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14582, 14578, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14584, 14580, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14586, 14582, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14588, 14584, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14590, 14586, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14592, 14588, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14594, 14590, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14596, 14592, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14598, 14594, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14600, 14596, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14602, 14598, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14604, 14600, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14606, 14602, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14608, 14604, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14610, 14606, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14612, 14608, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14614, 14610, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14616, 14612, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14618, 14614, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14620, 14616, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14622, 14618, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14624, 14620, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14626, 14622, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14628, 14624, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14630, 14626, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14632, 14628, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14634, 14630, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14636, 14632, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14638, 14634, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14640, 14636, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14642, 14638, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14644, 14640, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14646, 14642, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14648, 14644, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14650, 14646, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14652, 14648, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14654, 14650, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14656, 14652, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14658, 14654, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14660, 14656, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14662, 14658, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14664, 14660, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14666, 14662, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14668, 14664, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14670, 14666, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14672, 14668, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14674, 14670, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14676, 14672, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14678, 14674, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14680, 14676, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14682, 14678, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(14690, 14686, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16701, 14347, 2, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16703, 16696, 2, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16704, 16697, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16705, 16698, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16706, 16699, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16707, 16700, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16708, 16701, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16709, 16702, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16710, 16703, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16711, 16704, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16712, 16705, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16714, 16707, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16717, 16710, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16720, 16713, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16723, 16716, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16727, 16719, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16730, 16722, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16733, 16726, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16736, 16729, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16738, 16731, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16740, 16733, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16742, 16735, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16744, 16737, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16746, 16739, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16748, 16741, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16750, 16743, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16752, 16745, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16754, 16747, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16756, 16749, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16758, 16751, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16760, 16753, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16762, 16755, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16764, 16757, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16766, 16759, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16768, 16761, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16770, 16763, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16772, 16765, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16774, 16767, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16776, 16769, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16778, 16771, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16780, 16773, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16782, 16775, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16784, 16777, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16786, 16779, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16788, 16781, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16790, 16783, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16792, 16785, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16794, 16787, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16796, 16789, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16798, 16791, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16800, 16793, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16802, 16795, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16804, 16797, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16806, 16799, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16808, 16801, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16810, 16803, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16812, 16805, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16814, 16807, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16816, 16809, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16818, 16811, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16820, 16813, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16822, 16815, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16824, 16817, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16826, 16819, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16828, 16821, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16830, 16823, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16832, 16825, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16834, 16827, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16836, 16829, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16838, 16831, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16840, 16833, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16842, 16835, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16844, 16837, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16846, 16839, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16848, 16841, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16850, 16843, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16852, 16845, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16854, 16847, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16856, 16849, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16858, 16851, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16860, 16853, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16862, 16855, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16864, 16857, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16866, 16859, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16868, 16861, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16870, 16863, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16872, 16865, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16874, 16867, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16876, 16869, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16878, 16871, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16880, 16873, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16882, 16875, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16884, 16877, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16886, 16879, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16888, 16881, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16890, 16883, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16892, 16885, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16894, 16887, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16896, 16889, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16898, 16891, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16900, 16893, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16902, 16895, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16904, 16897, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16906, 16899, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16908, 16901, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16910, 16903, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16912, 16905, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16914, 16907, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16916, 16909, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16918, 16911, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16920, 16913, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16922, 16915, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16924, 16917, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16926, 16919, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16928, 16921, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16930, 16923, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16932, 16925, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16934, 16927, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16936, 16929, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16938, 16931, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16940, 16933, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16942, 16935, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16944, 16937, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16946, 16939, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16948, 16941, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16950, 16943, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16952, 16945, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16954, 16947, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16956, 16949, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16958, 16951, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16960, 16953, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16962, 16955, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16964, 16957, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16966, 16959, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16968, 16961, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16970, 16963, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16972, 16965, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16974, 16967, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16976, 16969, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16978, 16971, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16980, 16973, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16982, 16975, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16984, 16977, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16986, 16979, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16988, 16981, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16990, 16983, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16992, 16985, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16994, 16987, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16996, 16989, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(16998, 16991, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17000, 16993, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17002, 16995, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17004, 16997, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17006, 16999, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17008, 17001, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17010, 17003, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17012, 17005, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17014, 17007, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17016, 17009, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17018, 17011, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17020, 17013, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17022, 17015, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17024, 17017, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17026, 17019, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17028, 17021, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17030, 17023, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17032, 17025, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17034, 17027, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17036, 17029, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17038, 17031, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17041, 17033, 2, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17042, 17034, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17043, 17035, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17044, 17036, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17046, 17038, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17047, 17039, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17048, 17040, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17049, 17041, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17050, 17042, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17051, 17043, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17052, 17044, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17053, 17045, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17054, 17046, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17055, 17047, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17056, 17048, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17057, 17049, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17058, 17050, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17059, 17051, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17060, 17052, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17061, 17053, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17062, 17054, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17063, 17055, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17064, 17056, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17065, 17057, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17066, 17058, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17067, 17059, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17068, 17060, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17069, 17061, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17070, 17062, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17071, 17063, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17072, 17064, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17073, 17065, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17074, 17066, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17075, 17067, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17076, 17068, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17077, 17069, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17078, 17070, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17079, 17071, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17080, 17072, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17081, 17073, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17082, 17074, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17083, 17075, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17084, 17076, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17085, 17077, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17086, 17078, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17087, 17079, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17088, 17080, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17089, 17081, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17090, 17082, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17091, 17083, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17092, 17084, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17093, 17085, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17094, 17086, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17095, 17087, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17096, 17088, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17097, 17089, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17098, 17090, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17099, 17091, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17100, 17092, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17101, 17093, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17102, 17094, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17103, 17095, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17104, 17096, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17105, 17097, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17106, 17098, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17107, 17099, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17108, 17100, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17109, 17101, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17110, 17102, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17111, 17103, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17112, 17104, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17113, 17105, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17114, 17106, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17115, 17107, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17116, 17108, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17117, 17109, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17118, 17110, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17119, 17111, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17120, 17112, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17121, 17113, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17122, 17114, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17123, 17115, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17124, 17116, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17125, 17117, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17126, 17118, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17127, 17119, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17128, 17120, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17129, 17121, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17130, 17122, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17131, 17123, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17132, 17124, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17133, 17125, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17134, 17126, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17135, 17127, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17136, 17128, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17137, 17129, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17138, 17130, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17139, 17131, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17140, 17132, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17141, 17133, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17142, 17134, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17143, 17135, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17144, 17136, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17145, 17137, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17146, 17138, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17147, 17139, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17148, 17140, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17151, 17142, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17153, 17145, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17156, 17148, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17160, 17151, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17163, 17154, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17166, 17158, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17169, 17161, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17172, 17163, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17175, 17167, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17178, 17169, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17180, 17172, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17184, 17175, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17186, 17178, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17189, 17181, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17192, 17184, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17195, 17187, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17198, 17189, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17201, 17193, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17203, 17195, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17207, 17198, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17210, 17201, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17212, 17204, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17215, 17207, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17218, 17210, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17221, 17213, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17224, 17216, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17227, 17219, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17230, 17221, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17234, 17225, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17236, 17228, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17239, 17231, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17242, 17234, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17245, 17237, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17249, 17240, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17251, 17243, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17254, 17246, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17257, 17249, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17261, 17252, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17264, 17255, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17267, 17258, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17269, 17261, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17272, 17264, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17276, 17267, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17279, 17270, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17282, 17273, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17285, 17277, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17288, 17279, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17291, 17283, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17294, 17285, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17296, 17288, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17300, 17291, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17303, 17294, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17305, 17297, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17309, 17300, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17311, 17303, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17314, 17306, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17318, 17309, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17320, 17312, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17323, 17315, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17326, 17318, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(17329, 17321, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(27125, 27117, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(28802, 28794, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(28803, 28795, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(28804, 28796, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32789, 32781, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32791, 32783, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32793, 32785, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32795, 32787, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32797, 32789, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32799, 32791, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32801, 32793, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32803, 32795, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32805, 32797, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32807, 32799, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32809, 32801, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32811, 32803, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32813, 32805, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32815, 32807, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32817, 32809, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32819, 32811, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32821, 32813, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32823, 32815, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32825, 32817, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32827, 32819, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32829, 32821, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32831, 32823, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32833, 32825, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(32835, 32827, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41189, 41180, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41191, 41183, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41193, 41185, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41195, 41187, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41197, 41189, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41199, 41191, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41201, 41193, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41203, 41195, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41205, 41197, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41207, 41199, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41209, 41201, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41211, 41203, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41213, 41205, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41215, 41207, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41217, 41209, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41219, 41211, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41221, 41213, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41223, 41215, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41225, 41217, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41227, 41219, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41229, 41221, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41231, 41223, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41233, 41225, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(41235, 41227, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47531, 47521, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47533, 47524, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47535, 47526, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47537, 47528, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47539, 47530, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47541, 47532, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47543, 47534, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47545, 47536, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47547, 47538, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47549, 47540, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47551, 47542, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47553, 47544, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47555, 47546, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47557, 47548, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47559, 47550, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47561, 47552, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47563, 47554, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47565, 47556, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47567, 47558, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47569, 47560, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47571, 47562, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47573, 47564, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47575, 47566, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47577, 47568, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47723, 47714, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47724, 47715, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47725, 47716, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47726, 47717, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47728, 47719, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47732, 47721, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47735, 47725, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47738, 47729, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47741, 47732, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47744, 47735, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47747, 47738, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47751, 47741, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47754, 47744, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47756, 47747, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47759, 47750, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47762, 47753, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47765, 47755, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47768, 47758, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47771, 47762, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47774, 47765, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47776, 47767, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47779, 47769, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47782, 47772, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(47784, 47775, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49546, 49536, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49549, 49540, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49551, 49542, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49553, 49544, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49555, 49546, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49557, 49548, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49559, 49550, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49561, 49552, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49563, 49554, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49565, 49556, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49567, 49558, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49569, 49560, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49571, 49562, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49573, 49564, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49575, 49566, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49577, 49568, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49579, 49570, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49581, 49572, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49583, 49574, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49585, 49576, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49587, 49578, 4, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49589, 49580, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49591, 49582, 1, 1);
INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES(49593, 49584, 1, 1);

-- --------------------------------------------------------

--
-- Table structure for table `trip_vehicle_employees`
--

CREATE TABLE `trip_vehicle_employees` (
  `id` int(11) NOT NULL,
  `trip_vehicle_id` int(11) DEFAULT NULL,
  `employee_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `trip_vehicle_employees`
--

INSERT INTO `trip_vehicle_employees` (`id`, `trip_vehicle_id`, `employee_id`) VALUES(1, 15, 9);
INSERT INTO `trip_vehicle_employees` (`id`, `trip_vehicle_id`, `employee_id`) VALUES(2, 18, 8);
INSERT INTO `trip_vehicle_employees` (`id`, `trip_vehicle_id`, `employee_id`) VALUES(4, 17090, 7);
INSERT INTO `trip_vehicle_employees` (`id`, `trip_vehicle_id`, `employee_id`) VALUES(3, 17103, 4);

-- --------------------------------------------------------

--
-- Table structure for table `vehicles`
--

CREATE TABLE `vehicles` (
  `id` int(11) NOT NULL,
  `name` text NOT NULL,
  `seat_count` int(11) DEFAULT NULL,
  `type` varchar(20) DEFAULT NULL,
  `plate_number` varchar(20) DEFAULT NULL,
  `operator_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `vehicles`
--

INSERT INTO `vehicles` (`id`, `name`, `seat_count`, `type`, `plate_number`, `operator_id`) VALUES(1, 'Microbuz 20 locuri', 20, 'microbuz', 'BT22DMS', 2);
INSERT INTO `vehicles` (`id`, `name`, `seat_count`, `type`, `plate_number`, `operator_id`) VALUES(2, 'Autocar Scania', 50, 'autocar', 'IS33DMS', 2);
INSERT INTO `vehicles` (`id`, `name`, `seat_count`, `type`, `plate_number`, `operator_id`) VALUES(3, 'Autocar Mercedes', 51, 'autocar', 'BT21DMS', 2);
INSERT INTO `vehicles` (`id`, `name`, `seat_count`, `type`, `plate_number`, `operator_id`) VALUES(4, 'Microbuz', 20, 'microbuz', 'BT01PRI', 1);
INSERT INTO `vehicles` (`id`, `name`, `seat_count`, `type`, `plate_number`, `operator_id`) VALUES(5, 'Microbuz', 20, 'microbuz', 'BT02PRI', 1);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `agencies`
--
ALTER TABLE `agencies`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `audit_logs`
--
ALTER TABLE `audit_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_audit_created_at` (`created_at`),
  ADD KEY `idx_audit_action` (`action`),
  ADD KEY `idx_audit_entity_id` (`entity`,`entity_id`),
  ADD KEY `idx_audit_related_id` (`related_entity`,`related_id`);

--
-- Indexes for table `blacklist`
--
ALTER TABLE `blacklist`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `cash_handovers`
--
ALTER TABLE `cash_handovers`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `discount_types`
--
ALTER TABLE `discount_types`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `code` (`code`);

--
-- Indexes for table `employees`
--
ALTER TABLE `employees`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_employees_role` (`role`);

--
-- Indexes for table `invitations`
--
ALTER TABLE `invitations`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `token` (`token`),
  ADD KEY `fk_inv_operator` (`operator_id`);

--
-- Indexes for table `no_shows`
--
ALTER TABLE `no_shows`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `operators`
--
ALTER TABLE `operators`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `payments`
--
ALTER TABLE `payments`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `people`
--
ALTER TABLE `people`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ux_people_phone_active` (`phone`,`is_active`),
  ADD KEY `ix_people_owner_changed_by` (`owner_changed_by`),
  ADD KEY `ix_people_owner_changed_at` (`owner_changed_at`);

--
-- Indexes for table `price_lists`
--
ALTER TABLE `price_lists`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `price_list_items`
--
ALTER TABLE `price_list_items`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_price_list_items_unique` (`price_list_id`,`from_station_id`,`to_station_id`);

--
-- Indexes for table `pricing_categories`
--
ALTER TABLE `pricing_categories`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `promo_codes`
--
ALTER TABLE `promo_codes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `code` (`code`);

--
-- Indexes for table `promo_code_hours`
--
ALTER TABLE `promo_code_hours`
  ADD PRIMARY KEY (`promo_code_id`,`start_time`,`end_time`);

--
-- Indexes for table `promo_code_routes`
--
ALTER TABLE `promo_code_routes`
  ADD PRIMARY KEY (`promo_code_id`,`route_id`),
  ADD KEY `route_id` (`route_id`);

--
-- Indexes for table `promo_code_schedules`
--
ALTER TABLE `promo_code_schedules`
  ADD PRIMARY KEY (`promo_code_id`,`route_schedule_id`),
  ADD KEY `route_schedule_id` (`route_schedule_id`);

--
-- Indexes for table `promo_code_usages`
--
ALTER TABLE `promo_code_usages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `promo_code_id` (`promo_code_id`);

--
-- Indexes for table `promo_code_weekdays`
--
ALTER TABLE `promo_code_weekdays`
  ADD PRIMARY KEY (`promo_code_id`,`weekday`);

--
-- Indexes for table `reservations`
--
ALTER TABLE `reservations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `ix_res_trip_seat_status` (`trip_id`,`seat_id`,`status`),
  ADD KEY `ix_res_person_time` (`person_id`,`reservation_time`);

--
-- Indexes for table `reservations_backup`
--
ALTER TABLE `reservations_backup`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `reservation_discounts`
--
ALTER TABLE `reservation_discounts`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_resdisc_promo` (`promo_code_id`);

--
-- Indexes for table `reservation_events`
--
ALTER TABLE `reservation_events`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_reservation` (`reservation_id`);

--
-- Indexes for table `reservation_pricing`
--
ALTER TABLE `reservation_pricing`
  ADD PRIMARY KEY (`reservation_id`);

--
-- Indexes for table `routes`
--
ALTER TABLE `routes`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `route_schedules`
--
ALTER TABLE `route_schedules`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `route_schedule_discounts`
--
ALTER TABLE `route_schedule_discounts`
  ADD PRIMARY KEY (`discount_type_id`,`route_schedule_id`);

--
-- Indexes for table `route_stations`
--
ALTER TABLE `route_stations`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_route_station` (`route_id`,`station_id`),
  ADD KEY `idx_route_seq` (`route_id`,`sequence`);

--
-- Indexes for table `schedule_exceptions`
--
ALTER TABLE `schedule_exceptions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_schedule` (`schedule_id`),
  ADD KEY `idx_exception_date` (`exception_date`),
  ADD KEY `idx_weekday` (`weekday`),
  ADD KEY `idx_sched_date_week` (`schedule_id`,`exception_date`,`weekday`);

--
-- Indexes for table `seats`
--
ALTER TABLE `seats`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_vehicle_grid` (`vehicle_id`,`row`,`seat_col`),
  ADD UNIQUE KEY `uq_vehicle_label` (`vehicle_id`,`label`) USING HASH,
  ADD KEY `idx_pair` (`vehicle_id`,`pair_id`);

--
-- Indexes for table `sessions`
--
ALTER TABLE `sessions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `token_hash` (`token_hash`),
  ADD KEY `idx_sessions_emp` (`employee_id`),
  ADD KEY `idx_sessions_exp` (`expires_at`);

--
-- Indexes for table `stations`
--
ALTER TABLE `stations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `traveler_defaults`
--
ALTER TABLE `traveler_defaults`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `trips`
--
ALTER TABLE `trips`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_trips_route_date_time_vehicle` (`route_id`,`date`,`time`,`vehicle_id`);

--
-- Indexes for table `trip_stations`
--
ALTER TABLE `trip_stations`
  ADD PRIMARY KEY (`trip_id`,`station_id`),
  ADD UNIQUE KEY `uq_trip_seq` (`trip_id`,`sequence`),
  ADD KEY `fk_ts_station` (`station_id`);

--
-- Indexes for table `trip_vehicles`
--
ALTER TABLE `trip_vehicles`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_tv_trip_vehicle` (`trip_id`,`vehicle_id`),
  ADD KEY `idx_tv_trip` (`trip_id`),
  ADD KEY `idx_tv_vehicle` (`vehicle_id`);

--
-- Indexes for table `trip_vehicle_employees`
--
ALTER TABLE `trip_vehicle_employees`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_tve_trip_employee` (`trip_vehicle_id`,`employee_id`),
  ADD KEY `idx_tve_trip_vehicle_id` (`trip_vehicle_id`),
  ADD KEY `idx_tve_employee_id` (`employee_id`);

--
-- Indexes for table `vehicles`
--
ALTER TABLE `vehicles`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `agencies`
--
ALTER TABLE `agencies`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `audit_logs`
--
ALTER TABLE `audit_logs`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=36;

--
-- AUTO_INCREMENT for table `blacklist`
--
ALTER TABLE `blacklist`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `cash_handovers`
--
ALTER TABLE `cash_handovers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `discount_types`
--
ALTER TABLE `discount_types`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `employees`
--
ALTER TABLE `employees`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `invitations`
--
ALTER TABLE `invitations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `no_shows`
--
ALTER TABLE `no_shows`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT for table `operators`
--
ALTER TABLE `operators`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `payments`
--
ALTER TABLE `payments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT for table `people`
--
ALTER TABLE `people`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=63;

--
-- AUTO_INCREMENT for table `price_lists`
--
ALTER TABLE `price_lists`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `price_list_items`
--
ALTER TABLE `price_list_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `pricing_categories`
--
ALTER TABLE `pricing_categories`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `promo_codes`
--
ALTER TABLE `promo_codes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `promo_code_usages`
--
ALTER TABLE `promo_code_usages`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `reservations`
--
ALTER TABLE `reservations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=90;

--
-- AUTO_INCREMENT for table `reservations_backup`
--
ALTER TABLE `reservations_backup`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `reservation_discounts`
--
ALTER TABLE `reservation_discounts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `reservation_events`
--
ALTER TABLE `reservation_events`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=30;

--
-- AUTO_INCREMENT for table `route_schedules`
--
ALTER TABLE `route_schedules`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=25;

--
-- AUTO_INCREMENT for table `route_stations`
--
ALTER TABLE `route_stations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=70;

--
-- AUTO_INCREMENT for table `schedule_exceptions`
--
ALTER TABLE `schedule_exceptions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `seats`
--
ALTER TABLE `seats`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=451;

--
-- AUTO_INCREMENT for table `sessions`
--
ALTER TABLE `sessions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=30;

--
-- AUTO_INCREMENT for table `stations`
--
ALTER TABLE `stations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT for table `traveler_defaults`
--
ALTER TABLE `traveler_defaults`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT for table `trips`
--
ALTER TABLE `trips`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=49922;

--
-- AUTO_INCREMENT for table `trip_vehicles`
--
ALTER TABLE `trip_vehicles`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=49931;

--
-- AUTO_INCREMENT for table `trip_vehicle_employees`
--
ALTER TABLE `trip_vehicle_employees`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `vehicles`
--
ALTER TABLE `vehicles`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `invitations`
--
ALTER TABLE `invitations`
  ADD CONSTRAINT `fk_inv_operator` FOREIGN KEY (`operator_id`) REFERENCES `operators` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `promo_code_hours`
--
ALTER TABLE `promo_code_hours`
  ADD CONSTRAINT `fk_promo_hours_code` FOREIGN KEY (`promo_code_id`) REFERENCES `promo_codes` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `promo_code_routes`
--
ALTER TABLE `promo_code_routes`
  ADD CONSTRAINT `fk_promo_routes_code` FOREIGN KEY (`promo_code_id`) REFERENCES `promo_codes` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `promo_code_schedules`
--
ALTER TABLE `promo_code_schedules`
  ADD CONSTRAINT `fk_promo_sched_code` FOREIGN KEY (`promo_code_id`) REFERENCES `promo_codes` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `promo_code_usages`
--
ALTER TABLE `promo_code_usages`
  ADD CONSTRAINT `fk_promo_usages_code` FOREIGN KEY (`promo_code_id`) REFERENCES `promo_codes` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `promo_code_weekdays`
--
ALTER TABLE `promo_code_weekdays`
  ADD CONSTRAINT `fk_promo_weekdays_code` FOREIGN KEY (`promo_code_id`) REFERENCES `promo_codes` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `reservation_discounts`
--
ALTER TABLE `reservation_discounts`
  ADD CONSTRAINT `fk_resdisc_promo` FOREIGN KEY (`promo_code_id`) REFERENCES `promo_codes` (`id`);

--
-- Constraints for table `reservation_events`
--
ALTER TABLE `reservation_events`
  ADD CONSTRAINT `fk_reservation_events_res` FOREIGN KEY (`reservation_id`) REFERENCES `reservations` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `schedule_exceptions`
--
ALTER TABLE `schedule_exceptions`
  ADD CONSTRAINT `fk_se_schedule` FOREIGN KEY (`schedule_id`) REFERENCES `route_schedules` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `sessions`
--
ALTER TABLE `sessions`
  ADD CONSTRAINT `fk_sess_emp` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `trip_stations`
--
ALTER TABLE `trip_stations`
  ADD CONSTRAINT `fk_ts_station` FOREIGN KEY (`station_id`) REFERENCES `stations` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_ts_trip` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
