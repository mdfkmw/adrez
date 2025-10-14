-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: db:3306
-- Generation Time: Oct 14, 2025 at 03:41 PM
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

INSERT INTO `agencies` (`id`, `name`) VALUES
(1, 'Agenția Botoșani'),
(2, 'Agenția Iași'),
(3, 'Agenția Hârlău');

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

--
-- Dumping data for table `blacklist`
--

INSERT INTO `blacklist` (`id`, `person_id`, `reason`, `added_by_employee_id`, `created_at`) VALUES
(5, 14, 'Are multe neprezentari', 12, '2025-10-12 16:44:12');

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

INSERT INTO `discount_types` (`id`, `code`, `label`, `value_off`, `created_at`, `type`) VALUES
(1, 'pensionar', 'Pensionar - 50%', 50.00, '2025-07-28 15:25:12', 'percent'),
(2, 'copil', 'Copil < 12 ani - 50%', 50.00, '2025-07-28 15:25:58', 'percent'),
(3, 'das', 'DAS - 100%', 100.00, '2025-07-28 15:26:49', 'percent'),
(4, 'vip', 'VIP', 100.00, '2025-07-28 19:30:39', 'percent'),
(5, 'cea', 'mai jmechera', 60.00, '2025-08-01 21:05:05', 'fixed');

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
  `role` enum('driver','agent') NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `operator_id` int(11) NOT NULL DEFAULT 1,
  `agency_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `employees`
--

INSERT INTO `employees` (`id`, `name`, `phone`, `email`, `password_hash`, `role`, `active`, `created_at`, `operator_id`, `agency_id`) VALUES
(1, 'CucuBau', NULL, NULL, NULL, 'agent', 1, '2025-08-04 13:46:37', 2, 1),
(2, 'test', NULL, NULL, NULL, 'driver', 1, '2025-08-21 10:53:13', 2, NULL),
(3, 'Ion Popescu', '0740123456', NULL, NULL, 'driver', 1, '2025-07-09 09:46:32', 1, NULL),
(4, 'Silion Vasile Razvan', NULL, NULL, NULL, 'driver', 1, '2025-07-09 14:15:50', 2, NULL),
(5, 'Roșu Iulian', NULL, NULL, NULL, 'agent', 1, '2025-07-09 14:15:50', 2, 3),
(6, 'Petru Matei', NULL, NULL, NULL, 'driver', 1, '2025-07-09 14:15:50', 1, NULL),
(7, 'Guzic Bogdan Dumitru', NULL, NULL, NULL, 'driver', 1, '2025-07-09 14:15:50', 1, NULL),
(8, 'Daniel Calenciuc', NULL, NULL, NULL, 'agent', 1, '2025-08-21 10:49:42', 2, 2),
(9, 'Calenciuc Ema', '65465', NULL, NULL, 'agent', 1, '2025-08-21 10:52:26', 2, 3);

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

--
-- Dumping data for table `no_shows`
--

INSERT INTO `no_shows` (`id`, `person_id`, `trip_id`, `seat_id`, `reservation_id`, `board_station_id`, `exit_station_id`, `added_by_employee_id`, `created_at`) VALUES
(6, 15, 11263, 240, 16, 7, 6, 12, '2025-10-12 16:44:09'),
(7, 14, 25, 240, 15, 7, 6, 12, '2025-10-12 16:54:16'),
(8, 18, 27, 240, 20, 7, 6, 12, '2025-10-12 20:16:54');

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

INSERT INTO `operators` (`id`, `name`, `pos_endpoint`, `theme_color`) VALUES
(1, 'Pris-Com', 'https://pos.priscom.ro/pay', '#FF0000'),
(2, 'Auto-Dimas', 'https://pos.autodimas.ro/pay', '#0000FF');

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

--
-- Dumping data for table `payments`
--

INSERT INTO `payments` (`id`, `reservation_id`, `amount`, `status`, `payment_method`, `transaction_id`, `timestamp`, `deposited_at`, `deposited_by`, `collected_by`, `cash_handover_id`) VALUES
(7, 24, 1.00, 'paid', 'cash', NULL, '2025-10-14 10:42:58', NULL, NULL, NULL, NULL),
(8, 25, 0.10, 'paid', 'cash', NULL, '2025-10-14 10:52:02', NULL, NULL, NULL, NULL),
(9, 26, 0.10, 'paid', 'cash', NULL, '2025-10-14 10:54:29', NULL, NULL, NULL, NULL),
(10, 28, 0.10, 'paid', 'cash', NULL, '2025-10-14 11:40:21', NULL, NULL, NULL, NULL),
(11, 27, 0.10, 'paid', 'cash', NULL, '2025-10-14 11:41:27', NULL, NULL, NULL, NULL),
(12, 31, 0.10, 'paid', 'cash', NULL, '2025-10-14 12:19:09', NULL, NULL, NULL, NULL),
(13, 33, 0.10, 'paid', 'cash', NULL, '2025-10-14 12:38:19', NULL, NULL, NULL, NULL),
(14, 32, 0.10, 'paid', 'cash', NULL, '2025-10-14 12:38:25', NULL, NULL, NULL, NULL),
(15, 34, 0.10, 'paid', 'cash', NULL, '2025-10-14 12:38:44', NULL, NULL, NULL, NULL),
(16, 35, 0.10, 'paid', 'cash', NULL, '2025-10-14 12:39:37', NULL, NULL, NULL, NULL),
(17, 37, 0.10, 'paid', 'cash', NULL, '2025-10-14 12:57:46', NULL, NULL, NULL, NULL),
(18, 39, 0.05, 'paid', 'cash', NULL, '2025-10-14 12:58:28', NULL, NULL, NULL, NULL),
(19, 40, 0.05, 'paid', 'cash', NULL, '2025-10-14 12:58:44', NULL, NULL, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `people`
--

CREATE TABLE `people` (
  `id` int(11) NOT NULL,
  `name` text NOT NULL,
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

INSERT INTO `people` (`id`, `name`, `phone`, `owner_status`, `prev_owner_id`, `replaced_by_id`, `owner_changed_by`, `owner_changed_at`, `blacklist`, `whitelist`, `notes`, `notes_by`, `notes_at`, `updated_at`) VALUES
(15, 'cucuba', '1234567890', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-12 18:16:23'),
(18, 'iulian', '0743171315', 'active', 14, NULL, 1, '2025-10-12 17:18:07', 0, 0, 'magar', NULL, NULL, '2025-10-12 20:46:56'),
(19, '', '1234567892', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 10:04:46'),
(20, '', '4578410159', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 10:51:51'),
(21, 'huliganu', NULL, 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 10:54:29'),
(22, '', '84798646546', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 11:40:02'),
(23, '', '982340837465', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 11:40:10'),
(24, '', '23408293479823', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 11:43:20'),
(25, '', '6846565465', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 12:16:16'),
(26, '', '9865645465', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 12:19:06'),
(27, '', '64654654651', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 12:38:08'),
(28, '', '63453546565', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 12:38:15'),
(29, '', '68746546546', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 12:38:33'),
(30, '', '6543546546', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 12:39:34'),
(31, '', '68654654651', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 12:40:21'),
(32, '', '6543235435', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 12:57:43'),
(33, '', '543546543516', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 12:58:12'),
(34, '', '6543165465546', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 12:58:24'),
(35, '', '3454546545465', 'active', NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, '2025-10-14 12:58:41');

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

INSERT INTO `price_lists` (`id`, `name`, `version`, `effective_from`, `created_by`, `created_at`, `route_id`, `category_id`) VALUES
(1, '1-1-2025-10-11', 1, '2025-10-11', 1, '2025-10-11 18:47:01', 1, 1),
(2, '8-1-2025-10-11', 1, '2025-10-11', 1, '2025-10-11 19:50:15', 8, 1),
(3, '1-1-2025-10-14', 1, '2025-10-14', 1, '2025-10-14 10:03:58', 1, 1);

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

INSERT INTO `price_list_items` (`id`, `price`, `currency`, `price_return`, `price_list_id`, `from_station_id`, `to_station_id`) VALUES
(1, 50.00, 'RON', NULL, 1, 7, 6),
(2, 50.00, 'RON', NULL, 2, 6, 8),
(4, 0.10, 'RON', NULL, 3, 7, 6);

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

INSERT INTO `pricing_categories` (`id`, `name`, `description`, `active`) VALUES
(1, 'Normal', 'Preț standard pentru bilete individuale', 1),
(2, 'Online', 'Preț standard pentru bilete online', 1),
(3, 'Elev', 'Preț standard pentru elevi', 1),
(4, 'Student', 'Preț standard pentru studenți', 1);

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

INSERT INTO `reservations` (`id`, `trip_id`, `seat_id`, `person_id`, `reservation_time`, `status`, `observations`, `created_by`, `board_station_id`, `exit_station_id`) VALUES
(15, 25, 240, 14, '2025-10-12 16:43:37', 'active', NULL, 12, 7, 6),
(16, 11263, 240, 15, '2025-10-12 16:43:51', 'active', NULL, 12, 7, 6),
(17, 11263, 241, 14, '2025-10-12 16:44:03', 'active', NULL, 12, 7, 6),
(18, 11263, 241, 15, '2025-10-12 18:16:23', 'active', NULL, 12, 7, 6),
(19, 25, 240, 18, '2025-10-12 19:04:13', 'cancelled', NULL, 12, 7, 6),
(20, 27, 240, 18, '2025-10-12 19:23:26', 'active', NULL, 1, 7, 6),
(21, 49, 240, 15, '2025-10-13 05:46:38', 'active', NULL, 1, 7, 6),
(22, 49, 241, 15, '2025-10-13 05:47:33', 'active', NULL, 12, 7, 6),
(24, 73, 240, 19, '2025-10-14 10:04:46', 'active', NULL, 12, 7, 6),
(25, 73, 241, 20, '2025-10-14 10:51:51', 'active', NULL, 12, 7, 6),
(26, 73, 242, 21, '2025-10-14 10:54:29', 'active', NULL, 12, 7, 6),
(27, 73, 243, 22, '2025-10-14 11:40:02', 'active', NULL, 12, 7, 6),
(28, 73, 244, 23, '2025-10-14 11:40:10', 'active', NULL, 12, 7, 6),
(29, 73, 245, 24, '2025-10-14 11:43:20', 'active', NULL, 12, 7, 6),
(30, 73, 246, 25, '2025-10-14 12:16:16', 'active', NULL, 12, 7, 6),
(31, 73, 247, 26, '2025-10-14 12:19:06', 'active', NULL, 12, 7, 6),
(32, 73, 248, 27, '2025-10-14 12:38:09', 'active', NULL, 12, 7, 6),
(33, 73, 249, 28, '2025-10-14 12:38:15', 'active', NULL, 12, 7, 6),
(34, 73, 250, 29, '2025-10-14 12:38:33', 'active', NULL, 12, 7, 6),
(35, 73, 251, 30, '2025-10-14 12:39:34', 'active', NULL, 12, 7, 6),
(36, 73, 252, 31, '2025-10-14 12:40:21', 'active', NULL, 12, 7, 6),
(37, 73, 253, 32, '2025-10-14 12:57:43', 'active', NULL, 12, 7, 6),
(38, 73, 254, 33, '2025-10-14 12:58:12', 'active', NULL, 12, 7, 6),
(39, 73, 255, 34, '2025-10-14 12:58:24', 'active', NULL, 12, 7, 6),
(40, 73, 256, 35, '2025-10-14 12:58:41', 'active', NULL, 12, 7, 6);

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

INSERT INTO `reservations_backup` (`id`, `reservation_id`, `trip_id`, `seat_id`, `label`, `person_id`, `backup_time`, `old_vehicle_id`) VALUES
(1, 19, 25, 240, '', 18, '2025-10-12 19:21:44', NULL),
(2, 19, 25, 240, '', 18, '2025-10-12 19:23:26', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `reservation_discounts`
--

CREATE TABLE `reservation_discounts` (
  `id` int(11) NOT NULL,
  `reservation_id` int(11) NOT NULL,
  `discount_type_id` int(11) NOT NULL,
  `discount_amount` decimal(10,2) NOT NULL,
  `applied_at` datetime NOT NULL DEFAULT current_timestamp(),
  `discount_snapshot` decimal(5,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `reservation_discounts`
--

INSERT INTO `reservation_discounts` (`id`, `reservation_id`, `discount_type_id`, `discount_amount`, `applied_at`, `discount_snapshot`) VALUES
(1, 38, 2, 0.05, '2025-10-14 12:58:12', 50.00),
(2, 39, 2, 0.05, '2025-10-14 12:58:24', 50.00),
(3, 40, 2, 0.05, '2025-10-14 12:58:41', 50.00);

-- --------------------------------------------------------

--
-- Table structure for table `reservation_pricing`
--

CREATE TABLE `reservation_pricing` (
  `reservation_id` int(11) NOT NULL,
  `price_value` decimal(10,2) NOT NULL,
  `price_list_id` int(11) NOT NULL,
  `pricing_category_id` int(11) NOT NULL,
  `booking_channel` enum('online','agent') NOT NULL DEFAULT 'online',
  `employee_id` int(11) NOT NULL DEFAULT 12,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `reservation_pricing`
--

INSERT INTO `reservation_pricing` (`reservation_id`, `price_value`, `price_list_id`, `pricing_category_id`, `booking_channel`, `employee_id`, `created_at`, `updated_at`) VALUES
(12, 50.00, 1, 1, 'online', 12, '2025-10-12 11:22:10', '2025-10-12 11:22:10'),
(13, 50.00, 1, 1, 'online', 12, '2025-10-12 11:22:20', '2025-10-12 11:22:20'),
(14, 50.00, 1, 1, 'online', 12, '2025-10-12 14:06:21', '2025-10-12 14:06:21'),
(15, 50.00, 1, 1, 'online', 12, '2025-10-12 16:43:37', '2025-10-12 16:43:37'),
(16, 50.00, 1, 1, 'online', 12, '2025-10-12 16:43:51', '2025-10-12 16:43:51'),
(17, 50.00, 1, 1, 'online', 12, '2025-10-12 16:44:03', '2025-10-12 16:44:03'),
(18, 0.00, 1, 1, 'online', 12, '2025-10-12 18:16:23', '2025-10-12 18:16:23'),
(19, 50.00, 1, 1, 'online', 12, '2025-10-12 19:04:13', '2025-10-12 19:04:13'),
(20, 50.00, 1, 1, 'online', 12, '2025-10-12 19:23:26', '2025-10-12 19:23:26'),
(21, 50.00, 1, 1, 'online', 12, '2025-10-13 05:46:38', '2025-10-13 05:46:38'),
(22, 50.00, 1, 1, 'online', 12, '2025-10-13 05:47:33', '2025-10-13 05:47:33'),
(23, 50.00, 1, 1, 'online', 12, '2025-10-14 10:01:45', '2025-10-14 10:01:45'),
(24, 1.00, 3, 1, 'online', 12, '2025-10-14 10:04:46', '2025-10-14 10:04:46'),
(25, 0.10, 3, 1, 'online', 12, '2025-10-14 10:51:51', '2025-10-14 10:51:51'),
(26, 0.10, 3, 1, 'online', 12, '2025-10-14 10:54:29', '2025-10-14 10:54:29'),
(27, 0.10, 3, 1, 'online', 12, '2025-10-14 11:40:02', '2025-10-14 11:40:02'),
(28, 0.10, 3, 1, 'online', 12, '2025-10-14 11:40:10', '2025-10-14 11:40:10'),
(29, 0.10, 3, 1, 'online', 12, '2025-10-14 11:43:20', '2025-10-14 11:43:20'),
(30, 0.10, 3, 1, 'online', 12, '2025-10-14 12:16:16', '2025-10-14 12:16:16'),
(31, 0.10, 3, 1, 'online', 12, '2025-10-14 12:19:06', '2025-10-14 12:19:06'),
(32, 0.10, 3, 1, 'online', 12, '2025-10-14 12:38:09', '2025-10-14 12:38:09'),
(33, 0.10, 3, 1, 'online', 12, '2025-10-14 12:38:15', '2025-10-14 12:38:15'),
(34, 0.10, 3, 1, 'online', 12, '2025-10-14 12:38:33', '2025-10-14 12:38:33'),
(35, 0.10, 3, 1, 'online', 12, '2025-10-14 12:39:34', '2025-10-14 12:39:34'),
(36, 0.10, 3, 1, 'online', 12, '2025-10-14 12:40:21', '2025-10-14 12:40:21'),
(37, 0.10, 3, 1, 'online', 12, '2025-10-14 12:57:43', '2025-10-14 12:57:43'),
(38, 0.05, 3, 1, 'online', 12, '2025-10-14 12:58:12', '2025-10-14 12:58:12'),
(39, 0.05, 3, 1, 'online', 12, '2025-10-14 12:58:24', '2025-10-14 12:58:24'),
(40, 0.05, 3, 1, 'online', 12, '2025-10-14 12:58:41', '2025-10-14 12:58:41');

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

INSERT INTO `routes` (`id`, `name`, `order_index`, `opposite_route_id`, `direction`) VALUES
(1, 'Botoșani – Iași', 1, 7, 'tur'),
(2, 'Rădăuți – Iași', 10, 8, 'tur'),
(3, 'Botoșani – Brașov', 7, 5, 'tur'),
(4, 'Botoșani – București', 3, 6, 'tur'),
(5, 'Brașov – Botoșani', 8, 3, 'retur'),
(6, 'București – Botoșani', 4, 4, 'retur'),
(7, 'Iași – Botoșani', 2, 1, 'retur'),
(8, 'Iași – Rădăuți', 9, 2, 'retur'),
(9, 'Dorohoi – Botoșani – Iași', 5, 10, 'tur'),
(10, 'Iași – Botoșani – Dorohoi', 6, 9, 'retur');

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

INSERT INTO `route_schedules` (`id`, `route_id`, `departure`, `operator_id`, `direction`) VALUES
(1, 1, '06:00:00', 1, 'tur'),
(2, 1, '07:00:00', 1, 'tur'),
(3, 1, '09:00:00', 1, 'tur'),
(4, 1, '11:30:00', 2, 'retur'),
(5, 1, '13:30:00', 1, 'tur'),
(6, 1, '15:30:00', 1, 'tur'),
(7, 1, '17:00:00', 2, 'retur'),
(8, 1, '19:00:00', 2, 'retur'),
(9, 2, '08:00:00', 2, 'tur'),
(10, 3, '08:00:00', 2, 'tur'),
(11, 4, '21:00:00', 1, 'tur'),
(12, 5, '16:00:00', 2, 'retur'),
(13, 6, '14:00:00', 1, 'retur'),
(14, 7, '07:00:00', 2, 'tur'),
(15, 7, '10:00:00', 1, 'retur'),
(16, 7, '12:00:00', 1, 'retur'),
(17, 7, '13:00:00', 2, 'tur'),
(18, 7, '14:00:00', 1, 'retur'),
(19, 7, '15:00:00', 2, 'tur'),
(20, 7, '17:00:00', 1, 'retur'),
(21, 7, '19:00:00', 1, 'retur'),
(22, 8, '16:00:00', 2, 'retur'),
(23, 9, '07:00:00', 2, 'tur'),
(24, 10, '11:00:00', 2, 'retur');

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

INSERT INTO `route_schedule_discounts` (`discount_type_id`, `route_schedule_id`) VALUES
(2, 1),
(2, 2),
(2, 3),
(2, 4),
(2, 5),
(2, 6),
(2, 7),
(2, 8),
(2, 10),
(2, 11),
(2, 12),
(2, 13),
(2, 14),
(2, 15),
(2, 16),
(2, 17),
(2, 18),
(2, 19),
(2, 20),
(2, 21),
(2, 23),
(2, 24);

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

INSERT INTO `route_stations` (`id`, `route_id`, `station_id`, `sequence`, `distance_from_previous_km`, `travel_time_from_previous_minutes`, `dwell_time_minutes`, `geofence_type`, `geofence_radius_m`, `geofence_polygon`, `created_at`, `updated_at`) VALUES
(16, 4, 8, 1, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(17, 4, 2, 2, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(18, 4, 3, 3, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(19, 5, 4, 1, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(20, 5, 15, 2, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(21, 5, 1, 3, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(22, 5, 8, 4, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(27, 1, 7, 1, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:09:51', '2025-10-11 18:09:51'),
(28, 1, 14, 2, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:09:51', '2025-10-11 18:09:51'),
(29, 1, 5, 3, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:09:51', '2025-10-11 18:09:51'),
(30, 1, 11, 4, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:09:51', '2025-10-11 18:09:51'),
(31, 1, 6, 5, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:09:51', '2025-10-11 18:09:51'),
(32, 6, 3, 1, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-10-11 18:10:27', '2025-10-11 18:10:27'),
(33, 6, 2, 2, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:10:27', '2025-10-11 18:10:27'),
(34, 6, 7, 3, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:10:27', '2025-10-11 18:10:27'),
(38, 7, 6, 1, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:04', '2025-10-11 18:11:04'),
(39, 7, 11, 2, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:04', '2025-10-11 18:11:04'),
(40, 7, 7, 3, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:04', '2025-10-11 18:11:04'),
(41, 10, 6, 1, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:22', '2025-10-11 18:11:22'),
(42, 10, 7, 2, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:22', '2025-10-11 18:11:22'),
(43, 10, 9, 3, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:22', '2025-10-11 18:11:22'),
(44, 8, 6, 1, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:35', '2025-10-11 18:11:35'),
(45, 8, 8, 2, 0.00, 0, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:35', '2025-10-11 18:11:35'),
(49, 2, 8, 1, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:47', '2025-10-11 18:11:47'),
(50, 2, 10, 2, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:47', '2025-10-11 18:11:47'),
(51, 2, 6, 3, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-10-11 18:11:47', '2025-10-11 18:11:47'),
(64, 3, 7, 1, NULL, NULL, 0, 'polygon', NULL, 0xe6100000010300000001000000050000006c1857902aac3a40282cc9f4d7e14740d18829ce08b83a400354ba798cdd4740f8cced5a53a53a40956f5185fbdb47405b5779f82ba43a40536ee75142e247406c1857902aac3a40282cc9f4d7e14740, '2025-10-12 18:49:20', '2025-10-12 18:49:20'),
(65, 3, 5, 2, NULL, NULL, 0, 'circle', 2000.00, NULL, '2025-10-12 18:49:20', '2025-10-12 18:49:20'),
(66, 3, 4, 3, NULL, NULL, 0, 'circle', 2000.00, NULL, '2025-10-12 18:49:20', '2025-10-12 18:49:20'),
(67, 9, 9, 1, NULL, NULL, 0, 'circle', 683.00, NULL, '2025-10-12 18:53:23', '2025-10-12 18:53:23'),
(68, 9, 5, 2, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-10-12 18:53:23', '2025-10-12 18:53:23'),
(69, 9, 6, 3, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-10-12 18:53:23', '2025-10-12 18:53:23');

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

INSERT INTO `schedule_exceptions` (`id`, `schedule_id`, `exception_date`, `weekday`, `disable_run`, `disable_online`, `created_by_employee_id`, `created_at`) VALUES
(3, 1, '2025-10-15', NULL, 0, 0, 12, '2025-10-12 19:02:12');

-- --------------------------------------------------------

--
-- Table structure for table `seats`
--

CREATE TABLE `seats` (
  `id` int(11) NOT NULL,
  `vehicle_id` int(11) DEFAULT NULL,
  `seat_number` int(11) DEFAULT NULL,
  `position` varchar(20) DEFAULT NULL,
  `row` int(11) DEFAULT NULL,
  `seat_col` int(11) DEFAULT NULL,
  `is_available` tinyint(1) DEFAULT NULL,
  `label` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `seats`
--

INSERT INTO `seats` (`id`, `vehicle_id`, `seat_number`, `position`, `row`, `seat_col`, `is_available`, `label`) VALUES
(61, 1, 0, NULL, 0, 1, 1, 'Șofer'),
(62, 1, 20, NULL, 0, 4, 1, '20'),
(63, 1, 1, NULL, 1, 1, 1, '1'),
(64, 1, 2, NULL, 1, 2, 1, '2'),
(65, 1, 3, NULL, 1, 4, 1, '3'),
(66, 1, 4, NULL, 2, 1, 1, '4'),
(67, 1, 5, NULL, 2, 2, 1, '5'),
(68, 1, 6, NULL, 2, 4, 1, '6'),
(69, 1, 7, NULL, 3, 1, 1, '7'),
(70, 1, 8, NULL, 3, 2, 1, '8'),
(71, 1, 9, NULL, 3, 4, 1, '9'),
(72, 1, 10, NULL, 4, 1, 1, '10'),
(73, 1, 11, NULL, 4, 2, 1, '11'),
(74, 1, 12, NULL, 4, 4, 1, '12'),
(75, 1, 13, NULL, 5, 1, 1, '13'),
(76, 1, 14, NULL, 5, 2, 1, '14'),
(77, 1, 15, NULL, 5, 4, 1, '15'),
(78, 1, 16, NULL, 6, 1, 1, '16'),
(79, 1, 17, NULL, 6, 2, 1, '17'),
(80, 1, 18, NULL, 6, 3, 1, '18'),
(81, 1, 19, NULL, 6, 4, 1, '19'),
(84, 3, 0, NULL, 0, 1, 1, 'Șofer'),
(85, 3, 52, NULL, 0, 4, 1, 'Ghid'),
(86, 3, 1, NULL, 1, 1, 1, '1'),
(87, 3, 2, NULL, 1, 2, 1, '2'),
(88, 3, 3, NULL, 2, 1, 1, '3'),
(89, 3, 4, NULL, 2, 2, 1, '4'),
(90, 3, 5, NULL, 3, 1, 1, '5'),
(91, 3, 6, NULL, 3, 2, 1, '6'),
(92, 3, 7, NULL, 4, 1, 1, '7'),
(93, 3, 8, NULL, 4, 2, 1, '8'),
(94, 3, 9, NULL, 5, 1, 1, '9'),
(95, 3, 10, NULL, 5, 2, 1, '10'),
(96, 3, 11, NULL, 6, 1, 1, '11'),
(97, 3, 12, NULL, 6, 2, 1, '12'),
(98, 3, 13, NULL, 7, 1, 1, '13'),
(99, 3, 14, NULL, 7, 2, 1, '14'),
(100, 3, 15, NULL, 8, 1, 1, '15'),
(101, 3, 16, NULL, 8, 2, 1, '16'),
(102, 3, 17, NULL, 9, 1, 1, '17'),
(103, 3, 18, NULL, 9, 2, 1, '18'),
(104, 3, 19, NULL, 10, 1, 1, '19'),
(105, 3, 20, NULL, 10, 2, 1, '20'),
(106, 3, 21, NULL, 11, 1, 1, '21'),
(107, 3, 22, NULL, 11, 2, 1, '22'),
(108, 3, 23, NULL, 12, 1, 1, '23'),
(109, 3, 24, NULL, 12, 2, 1, '24'),
(110, 3, 25, NULL, 13, 1, 1, '25'),
(111, 3, 26, NULL, 13, 2, 1, '26'),
(112, 3, 27, NULL, 1, 3, 1, '27'),
(113, 3, 28, NULL, 1, 4, 1, '28'),
(114, 3, 29, NULL, 2, 3, 1, '29'),
(115, 3, 30, NULL, 2, 4, 1, '30'),
(116, 3, 31, NULL, 3, 3, 1, '31'),
(117, 3, 32, NULL, 3, 4, 1, '32'),
(118, 3, 33, NULL, 4, 3, 1, '33'),
(119, 3, 34, NULL, 4, 4, 1, '34'),
(120, 3, 35, NULL, 5, 3, 1, '35'),
(121, 3, 36, NULL, 5, 4, 1, '36'),
(122, 3, 37, NULL, 6, 3, 1, '37'),
(123, 3, 38, NULL, 6, 4, 1, '38'),
(124, 3, 39, NULL, 8, 3, 1, '39'),
(125, 3, 40, NULL, 8, 4, 1, '40'),
(126, 3, 41, NULL, 9, 3, 1, '41'),
(127, 3, 42, NULL, 9, 4, 1, '42'),
(128, 3, 43, NULL, 10, 3, 1, '43'),
(129, 3, 44, NULL, 10, 4, 1, '44'),
(130, 3, 45, NULL, 11, 3, 1, '45'),
(131, 3, 46, NULL, 11, 4, 1, '46'),
(132, 3, 47, NULL, 12, 3, 1, '47'),
(133, 3, 48, NULL, 12, 4, 1, '48'),
(134, 3, 49, NULL, 13, 3, 1, '49'),
(135, 3, 50, NULL, 13, 4, 1, '50'),
(187, 2, 0, 'driver', 0, 1, 1, 'Șofer'),
(188, 2, 50, NULL, 0, 5, 1, '50'),
(189, 2, 1, NULL, 1, 1, 1, '1'),
(190, 2, 2, NULL, 1, 2, 1, '2'),
(191, 2, 3, NULL, 1, 4, 1, '3'),
(192, 2, 4, NULL, 1, 5, 1, '4'),
(193, 2, 5, NULL, 2, 1, 1, '5'),
(194, 2, 6, NULL, 2, 2, 1, '6'),
(195, 2, 7, NULL, 2, 4, 1, '7'),
(196, 2, 8, NULL, 2, 5, 1, '8'),
(197, 2, 9, NULL, 3, 1, 1, '9'),
(198, 2, 10, NULL, 3, 2, 1, '10'),
(199, 2, 11, NULL, 3, 4, 1, '11'),
(200, 2, 12, NULL, 3, 5, 1, '12'),
(201, 2, 13, NULL, 4, 1, 1, '13'),
(202, 2, 14, NULL, 4, 2, 1, '14'),
(203, 2, 15, NULL, 4, 4, 1, '15'),
(204, 2, 16, NULL, 4, 5, 1, '16'),
(205, 2, 17, NULL, 5, 1, 1, '17'),
(206, 2, 18, NULL, 5, 2, 1, '18'),
(207, 2, 19, NULL, 5, 4, 1, '19'),
(208, 2, 20, NULL, 5, 5, 1, '20'),
(209, 2, 21, NULL, 6, 1, 1, '21'),
(210, 2, 22, NULL, 6, 2, 1, '22'),
(211, 2, 23, NULL, 7, 1, 1, '23'),
(212, 2, 24, NULL, 7, 2, 1, '24'),
(213, 2, 25, NULL, 8, 1, 1, '25'),
(214, 2, 26, NULL, 8, 2, 1, '26'),
(215, 2, 27, NULL, 8, 4, 1, '27'),
(216, 2, 28, NULL, 8, 5, 1, '28'),
(217, 2, 29, NULL, 9, 1, 1, '29'),
(218, 2, 30, NULL, 9, 2, 1, '30'),
(219, 2, 31, NULL, 9, 4, 1, '31'),
(220, 2, 32, NULL, 9, 5, 1, '32'),
(221, 2, 33, NULL, 10, 1, 1, '33'),
(222, 2, 34, NULL, 10, 2, 1, '34'),
(223, 2, 35, NULL, 10, 4, 1, '35'),
(224, 2, 36, NULL, 10, 5, 1, '36'),
(225, 2, 37, NULL, 11, 1, 1, '37'),
(226, 2, 38, NULL, 11, 2, 1, '38'),
(227, 2, 39, NULL, 11, 4, 1, '39'),
(228, 2, 40, NULL, 11, 5, 1, '40'),
(229, 2, 41, NULL, 12, 1, 1, '41'),
(230, 2, 42, NULL, 12, 2, 1, '42'),
(231, 2, 43, NULL, 12, 4, 1, '43'),
(232, 2, 44, NULL, 12, 5, 1, '44'),
(233, 2, 45, NULL, 13, 1, 1, '45'),
(234, 2, 46, NULL, 13, 2, 1, '46'),
(235, 2, 47, NULL, 13, 3, 1, '47'),
(236, 2, 48, NULL, 13, 4, 1, '48'),
(237, 2, 49, NULL, 13, 5, 1, '49'),
(238, 4, 0, NULL, 0, 1, 1, 'Șofer'),
(239, 4, 20, NULL, 0, 4, 1, '20'),
(240, 4, 1, NULL, 1, 1, 1, '1'),
(241, 4, 2, NULL, 1, 2, 1, '2'),
(242, 4, 3, NULL, 1, 4, 1, '3'),
(243, 4, 4, NULL, 2, 1, 1, '4'),
(244, 4, 5, NULL, 2, 2, 1, '5'),
(245, 4, 6, NULL, 2, 4, 1, '6'),
(246, 4, 7, NULL, 3, 1, 1, '7'),
(247, 4, 8, NULL, 3, 2, 1, '8'),
(248, 4, 9, NULL, 3, 4, 1, '9'),
(249, 4, 10, NULL, 4, 1, 1, '10'),
(250, 4, 11, NULL, 4, 2, 1, '11'),
(251, 4, 12, NULL, 4, 4, 1, '12'),
(252, 4, 13, NULL, 5, 1, 1, '13'),
(253, 4, 14, NULL, 5, 2, 1, '14'),
(254, 4, 15, NULL, 5, 4, 1, '15'),
(255, 4, 16, NULL, 6, 1, 1, '16'),
(256, 4, 17, NULL, 6, 2, 1, '17'),
(257, 4, 18, NULL, 6, 3, 1, '18'),
(258, 4, 19, NULL, 6, 4, 1, '19'),
(259, 5, 0, NULL, 0, 1, 1, 'Șofer'),
(260, 5, 20, NULL, 0, 4, 1, '20'),
(261, 5, 1, NULL, 1, 1, 1, '1'),
(262, 5, 2, NULL, 1, 2, 1, '2'),
(263, 5, 3, NULL, 1, 4, 1, '3'),
(264, 5, 4, NULL, 2, 1, 1, '4'),
(265, 5, 5, NULL, 2, 2, 1, '5'),
(266, 5, 6, NULL, 2, 4, 1, '6'),
(267, 5, 7, NULL, 3, 1, 1, '7'),
(268, 5, 8, NULL, 3, 2, 1, '8'),
(269, 5, 9, NULL, 3, 4, 1, '9'),
(270, 5, 10, NULL, 4, 1, 1, '10'),
(271, 5, 11, NULL, 4, 2, 1, '11'),
(272, 5, 12, NULL, 4, 4, 1, '12'),
(273, 5, 13, NULL, 5, 1, 1, '13'),
(274, 5, 14, NULL, 5, 2, 1, '14'),
(275, 5, 15, NULL, 5, 4, 1, '15'),
(276, 5, 16, NULL, 6, 1, 1, '16'),
(277, 5, 17, NULL, 6, 2, 1, '17'),
(278, 5, 18, NULL, 6, 3, 1, '18'),
(279, 5, 19, NULL, 6, 4, 1, '19');

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

INSERT INTO `stations` (`id`, `name`, `locality`, `county`, `latitude`, `longitude`, `created_at`, `updated_at`) VALUES
(1, 'Suceava', 'Suceava', NULL, 47.64622921, 26.25683733, '2025-09-23 20:49:00', '2025-10-04 15:07:52'),
(2, 'Focșani', 'Focșani', NULL, 45.69303229, 27.19685926, '2025-09-23 20:49:00', '2025-10-04 15:06:43'),
(3, 'București', 'București', NULL, 44.43302028, 26.10429666, '2025-09-23 20:49:00', '2025-10-04 15:05:32'),
(4, 'Brașov', 'Brașov', NULL, 45.64571325, 25.57928619, '2025-09-23 20:49:00', '2025-10-04 15:05:44'),
(5, 'Flamanzi', 'Flamanzi', NULL, 47.56004767, 26.88260433, '2025-09-23 20:49:00', '2025-10-04 15:06:34'),
(6, 'Iași', 'Iași', NULL, 47.15221227, 27.60088813, '2025-09-23 20:49:00', '2025-10-04 15:07:23'),
(7, 'Botoșani', 'Botoșani', NULL, 47.74559429, 26.66634352, '2025-09-23 20:49:00', '2025-10-04 15:08:11'),
(8, 'Rădăuți', 'Rădăuți', NULL, 47.84576105, 25.92324273, '2025-09-23 20:49:00', '2025-10-04 15:07:44'),
(9, 'Dorohoi', 'Dorohoi', NULL, 47.95282338, 26.39650703, '2025-09-23 20:49:00', '2025-10-04 15:06:25'),
(10, 'Șendriceni', 'Șendriceni', NULL, 47.77842032, 26.39675549, '2025-09-23 20:49:00', '2025-10-04 15:08:01'),
(11, 'Rădeni', 'Rădeni', NULL, 47.51324461, 26.90207136, '2025-09-23 20:49:00', '2025-10-04 15:07:36'),
(12, 'Frumușica', 'Frumușica', NULL, 47.53052291, 26.89955637, '2025-09-23 20:49:00', '2025-10-04 15:06:55'),
(14, 'Buda', 'Buda', NULL, 47.62720367, 26.81294511, '2025-09-23 20:49:00', '2025-10-04 15:05:58'),
(15, 'Bacău', 'Bacău', '', 46.55541503, 26.94994927, '2025-09-23 20:49:00', '2025-10-11 17:44:16');

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

INSERT INTO `trips` (`id`, `route_id`, `vehicle_id`, `date`, `time`, `disabled`, `route_schedule_id`) VALUES
(1, 1, 4, '2025-10-11', '06:00:00', 0, 1),
(2, 1, 5, '2025-10-11', '07:00:00', 0, 2),
(3, 1, 4, '2025-10-11', '09:00:00', 0, 3),
(4, 1, 3, '2025-10-11', '11:30:00', 0, 4),
(5, 1, 4, '2025-10-11', '13:30:00', 0, 5),
(6, 1, 4, '2025-10-11', '15:30:00', 0, 6),
(7, 1, 1, '2025-10-11', '17:00:00', 0, 7),
(8, 1, 1, '2025-10-11', '19:00:00', 0, 8),
(9, 2, 1, '2025-10-11', '08:00:00', 0, 9),
(10, 3, 1, '2025-10-11', '08:00:00', 0, 10),
(11, 4, 4, '2025-10-11', '21:00:00', 0, 11),
(12, 5, 1, '2025-10-11', '16:00:00', 0, 12),
(13, 6, 4, '2025-10-11', '14:00:00', 0, 13),
(14, 7, 1, '2025-10-11', '07:00:00', 0, 14),
(15, 7, 4, '2025-10-11', '10:00:00', 0, 15),
(16, 7, 4, '2025-10-11', '12:00:00', 0, 16),
(17, 7, 1, '2025-10-11', '13:00:00', 0, 17),
(18, 7, 4, '2025-10-11', '14:00:00', 0, 18),
(19, 7, 1, '2025-10-11', '15:00:00', 0, 19),
(20, 7, 4, '2025-10-11', '17:00:00', 0, 20),
(21, 7, 4, '2025-10-11', '19:00:00', 0, 21),
(22, 8, 1, '2025-10-11', '16:00:00', 0, 22),
(23, 9, 1, '2025-10-11', '07:00:00', 0, 23),
(24, 10, 1, '2025-10-11', '11:00:00', 0, 24),
(25, 1, 4, '2025-10-12', '06:00:00', 0, 1),
(26, 1, 4, '2025-10-12', '07:00:00', 0, 2),
(27, 1, 4, '2025-10-12', '09:00:00', 0, 3),
(28, 1, 1, '2025-10-12', '11:30:00', 0, 4),
(29, 1, 4, '2025-10-12', '13:30:00', 0, 5),
(30, 1, 4, '2025-10-12', '15:30:00', 0, 6),
(31, 1, 1, '2025-10-12', '17:00:00', 0, 7),
(32, 1, 1, '2025-10-12', '19:00:00', 0, 8),
(33, 2, 1, '2025-10-12', '08:00:00', 0, 9),
(34, 3, 1, '2025-10-12', '08:00:00', 0, 10),
(35, 4, 4, '2025-10-12', '21:00:00', 0, 11),
(36, 5, 1, '2025-10-12', '16:00:00', 0, 12),
(37, 6, 4, '2025-10-12', '14:00:00', 0, 13),
(38, 7, 1, '2025-10-12', '07:00:00', 0, 14),
(39, 7, 4, '2025-10-12', '10:00:00', 0, 15),
(40, 7, 4, '2025-10-12', '12:00:00', 0, 16),
(41, 7, 1, '2025-10-12', '13:00:00', 0, 17),
(42, 7, 4, '2025-10-12', '14:00:00', 0, 18),
(43, 7, 1, '2025-10-12', '15:00:00', 0, 19),
(44, 7, 4, '2025-10-12', '17:00:00', 0, 20),
(45, 7, 4, '2025-10-12', '19:00:00', 0, 21),
(46, 8, 1, '2025-10-12', '16:00:00', 0, 22),
(47, 9, 1, '2025-10-12', '07:00:00', 0, 23),
(48, 10, 1, '2025-10-12', '11:00:00', 0, 24),
(49, 1, 4, '2025-10-13', '06:00:00', 0, 1),
(50, 1, 4, '2025-10-13', '07:00:00', 0, 2),
(51, 1, 4, '2025-10-13', '09:00:00', 0, 3),
(52, 1, 1, '2025-10-13', '11:30:00', 0, 4),
(53, 1, 4, '2025-10-13', '13:30:00', 0, 5),
(54, 1, 4, '2025-10-13', '15:30:00', 0, 6),
(55, 1, 1, '2025-10-13', '17:00:00', 0, 7),
(56, 1, 1, '2025-10-13', '19:00:00', 0, 8),
(57, 2, 1, '2025-10-13', '08:00:00', 0, 9),
(58, 3, 1, '2025-10-13', '08:00:00', 0, 10),
(59, 4, 4, '2025-10-13', '21:00:00', 0, 11),
(60, 5, 1, '2025-10-13', '16:00:00', 0, 12),
(61, 6, 4, '2025-10-13', '14:00:00', 0, 13),
(62, 7, 1, '2025-10-13', '07:00:00', 0, 14),
(63, 7, 4, '2025-10-13', '10:00:00', 0, 15),
(64, 7, 4, '2025-10-13', '12:00:00', 0, 16),
(65, 7, 1, '2025-10-13', '13:00:00', 0, 17),
(66, 7, 4, '2025-10-13', '14:00:00', 0, 18),
(67, 7, 1, '2025-10-13', '15:00:00', 0, 19),
(68, 7, 4, '2025-10-13', '17:00:00', 0, 20),
(69, 7, 4, '2025-10-13', '19:00:00', 0, 21),
(70, 8, 1, '2025-10-13', '16:00:00', 0, 22),
(71, 9, 1, '2025-10-13', '07:00:00', 0, 23),
(72, 10, 1, '2025-10-13', '11:00:00', 0, 24),
(73, 1, 4, '2025-10-14', '06:00:00', 0, 1),
(74, 1, 4, '2025-10-14', '07:00:00', 0, 2),
(75, 1, 4, '2025-10-14', '09:00:00', 0, 3),
(76, 1, 1, '2025-10-14', '11:30:00', 0, 4),
(77, 1, 4, '2025-10-14', '13:30:00', 0, 5),
(78, 1, 4, '2025-10-14', '15:30:00', 0, 6),
(79, 1, 1, '2025-10-14', '17:00:00', 0, 7),
(80, 1, 1, '2025-10-14', '19:00:00', 0, 8),
(81, 2, 1, '2025-10-14', '08:00:00', 0, 9),
(82, 3, 1, '2025-10-14', '08:00:00', 0, 10),
(83, 4, 4, '2025-10-14', '21:00:00', 0, 11),
(84, 5, 1, '2025-10-14', '16:00:00', 0, 12),
(85, 6, 4, '2025-10-14', '14:00:00', 0, 13),
(86, 7, 1, '2025-10-14', '07:00:00', 0, 14),
(87, 7, 4, '2025-10-14', '10:00:00', 0, 15),
(88, 7, 4, '2025-10-14', '12:00:00', 0, 16),
(89, 7, 1, '2025-10-14', '13:00:00', 0, 17),
(90, 7, 4, '2025-10-14', '14:00:00', 0, 18),
(91, 7, 1, '2025-10-14', '15:00:00', 0, 19),
(92, 7, 4, '2025-10-14', '17:00:00', 0, 20),
(93, 7, 4, '2025-10-14', '19:00:00', 0, 21),
(94, 8, 1, '2025-10-14', '16:00:00', 0, 22),
(95, 9, 1, '2025-10-14', '07:00:00', 0, 23),
(96, 10, 1, '2025-10-14', '11:00:00', 0, 24),
(97, 1, 4, '2025-10-15', '06:00:00', 0, 1),
(98, 1, 4, '2025-10-15', '07:00:00', 0, 2),
(99, 1, 4, '2025-10-15', '09:00:00', 0, 3),
(100, 1, 1, '2025-10-15', '11:30:00', 0, 4),
(101, 1, 4, '2025-10-15', '13:30:00', 0, 5),
(102, 1, 4, '2025-10-15', '15:30:00', 0, 6),
(103, 1, 1, '2025-10-15', '17:00:00', 0, 7),
(104, 1, 1, '2025-10-15', '19:00:00', 0, 8),
(105, 2, 1, '2025-10-15', '08:00:00', 0, 9),
(106, 3, 1, '2025-10-15', '08:00:00', 0, 10),
(107, 4, 4, '2025-10-15', '21:00:00', 0, 11),
(108, 5, 1, '2025-10-15', '16:00:00', 0, 12),
(109, 6, 4, '2025-10-15', '14:00:00', 0, 13),
(110, 7, 1, '2025-10-15', '07:00:00', 0, 14),
(111, 7, 4, '2025-10-15', '10:00:00', 0, 15),
(112, 7, 4, '2025-10-15', '12:00:00', 0, 16),
(113, 7, 1, '2025-10-15', '13:00:00', 0, 17),
(114, 7, 4, '2025-10-15', '14:00:00', 0, 18),
(115, 7, 1, '2025-10-15', '15:00:00', 0, 19),
(116, 7, 4, '2025-10-15', '17:00:00', 0, 20),
(117, 7, 4, '2025-10-15', '19:00:00', 0, 21),
(118, 8, 1, '2025-10-15', '16:00:00', 0, 22),
(119, 9, 1, '2025-10-15', '07:00:00', 0, 23),
(120, 10, 1, '2025-10-15', '11:00:00', 0, 24),
(121, 1, 4, '2025-10-16', '06:00:00', 0, 1),
(122, 1, 4, '2025-10-16', '07:00:00', 0, 2),
(123, 1, 4, '2025-10-16', '09:00:00', 0, 3),
(124, 1, 1, '2025-10-16', '11:30:00', 0, 4),
(125, 1, 4, '2025-10-16', '13:30:00', 0, 5),
(126, 1, 4, '2025-10-16', '15:30:00', 0, 6),
(127, 1, 1, '2025-10-16', '17:00:00', 0, 7),
(128, 1, 1, '2025-10-16', '19:00:00', 0, 8),
(129, 2, 1, '2025-10-16', '08:00:00', 0, 9),
(130, 3, 1, '2025-10-16', '08:00:00', 0, 10),
(131, 4, 4, '2025-10-16', '21:00:00', 0, 11),
(132, 5, 1, '2025-10-16', '16:00:00', 0, 12),
(133, 6, 4, '2025-10-16', '14:00:00', 0, 13),
(134, 7, 1, '2025-10-16', '07:00:00', 0, 14),
(135, 7, 4, '2025-10-16', '10:00:00', 0, 15),
(136, 7, 4, '2025-10-16', '12:00:00', 0, 16),
(137, 7, 1, '2025-10-16', '13:00:00', 0, 17),
(138, 7, 4, '2025-10-16', '14:00:00', 0, 18),
(139, 7, 1, '2025-10-16', '15:00:00', 0, 19),
(140, 7, 4, '2025-10-16', '17:00:00', 0, 20),
(141, 7, 4, '2025-10-16', '19:00:00', 0, 21),
(142, 8, 1, '2025-10-16', '16:00:00', 0, 22),
(143, 9, 1, '2025-10-16', '07:00:00', 0, 23),
(144, 10, 1, '2025-10-16', '11:00:00', 0, 24),
(145, 1, 4, '2025-10-17', '06:00:00', 0, 1),
(146, 1, 4, '2025-10-17', '07:00:00', 0, 2),
(147, 1, 4, '2025-10-17', '09:00:00', 0, 3),
(148, 1, 1, '2025-10-17', '11:30:00', 0, 4),
(149, 1, 4, '2025-10-17', '13:30:00', 0, 5),
(150, 1, 4, '2025-10-17', '15:30:00', 0, 6),
(151, 1, 1, '2025-10-17', '17:00:00', 0, 7),
(152, 1, 1, '2025-10-17', '19:00:00', 0, 8),
(153, 2, 1, '2025-10-17', '08:00:00', 0, 9),
(154, 3, 1, '2025-10-17', '08:00:00', 0, 10),
(155, 4, 4, '2025-10-17', '21:00:00', 0, 11),
(156, 5, 1, '2025-10-17', '16:00:00', 0, 12),
(157, 6, 4, '2025-10-17', '14:00:00', 0, 13),
(158, 7, 1, '2025-10-17', '07:00:00', 0, 14),
(159, 7, 4, '2025-10-17', '10:00:00', 0, 15),
(160, 7, 4, '2025-10-17', '12:00:00', 0, 16),
(161, 7, 1, '2025-10-17', '13:00:00', 0, 17),
(162, 7, 4, '2025-10-17', '14:00:00', 0, 18),
(163, 7, 1, '2025-10-17', '15:00:00', 0, 19),
(164, 7, 4, '2025-10-17', '17:00:00', 0, 20),
(165, 7, 4, '2025-10-17', '19:00:00', 0, 21),
(166, 8, 1, '2025-10-17', '16:00:00', 0, 22),
(167, 9, 1, '2025-10-17', '07:00:00', 0, 23),
(168, 10, 1, '2025-10-17', '11:00:00', 0, 24),
(10921, 1, 4, '2025-10-19', '06:00:00', 0, 1),
(10922, 7, 1, '2025-10-23', '07:00:00', 0, 14),
(10923, 7, 1, '2025-10-23', '15:00:00', 0, 19),
(10924, 1, 4, '2025-10-23', '06:00:00', 0, 1),
(10925, 1, 4, '2025-10-23', '07:00:00', 0, 2),
(11138, 1, 4, '2025-10-18', '06:00:00', 0, 1),
(11142, 1, 4, '2025-10-18', '07:00:00', 0, 2),
(11144, 1, 4, '2025-10-18', '09:00:00', 0, 3),
(11147, 1, 1, '2025-10-18', '11:30:00', 0, 4),
(11149, 1, 4, '2025-10-18', '13:30:00', 0, 5),
(11151, 1, 4, '2025-10-18', '15:30:00', 0, 6),
(11154, 1, 1, '2025-10-18', '17:00:00', 0, 7),
(11156, 1, 1, '2025-10-18', '19:00:00', 0, 8),
(11159, 2, 1, '2025-10-18', '08:00:00', 0, 9),
(11161, 3, 1, '2025-10-18', '08:00:00', 0, 10),
(11163, 4, 4, '2025-10-18', '21:00:00', 0, 11),
(11166, 5, 1, '2025-10-18', '16:00:00', 0, 12),
(11168, 6, 4, '2025-10-18', '14:00:00', 0, 13),
(11171, 7, 1, '2025-10-18', '07:00:00', 0, 14),
(11173, 7, 4, '2025-10-18', '10:00:00', 0, 15),
(11176, 7, 4, '2025-10-18', '12:00:00', 0, 16),
(11178, 7, 1, '2025-10-18', '13:00:00', 0, 17),
(11181, 7, 4, '2025-10-18', '14:00:00', 0, 18),
(11183, 7, 1, '2025-10-18', '15:00:00', 0, 19),
(11185, 7, 4, '2025-10-18', '17:00:00', 0, 20),
(11188, 7, 4, '2025-10-18', '19:00:00', 0, 21),
(11190, 8, 1, '2025-10-18', '16:00:00', 0, 22),
(11193, 9, 1, '2025-10-18', '07:00:00', 0, 23),
(11196, 10, 1, '2025-10-18', '11:00:00', 0, 24),
(11262, 1, 4, '2025-10-10', '06:00:00', 0, 1),
(11263, 1, 4, '2025-10-10', '07:00:00', 0, 2),
(11600, 1, 4, '2025-10-30', '13:30:00', 0, 5),
(11601, 1, 1, '2025-10-30', '19:00:00', 0, 8),
(11602, 2, 1, '2025-10-30', '08:00:00', 0, 9),
(11603, 1, 4, '2025-10-30', '07:00:00', 0, 2),
(11604, 1, 4, '2025-10-30', '06:00:00', 0, 1),
(11605, 1, 4, '2025-10-10', '09:00:00', 0, 3),
(13286, 1, 1, '2025-10-10', '11:30:00', 0, 4),
(13287, 1, 4, '2025-10-10', '13:30:00', 0, 5),
(13288, 1, 1, '2025-10-10', '17:00:00', 0, 7),
(13289, 1, 4, '2025-10-10', '15:30:00', 0, 6),
(13290, 1, 4, '2025-10-09', '06:00:00', 0, 1),
(13291, 1, 4, '2025-10-08', '06:00:00', 0, 1),
(13292, 1, 4, '2025-10-08', '07:00:00', 0, 2),
(13293, 1, 4, '2025-10-07', '07:00:00', 0, 2),
(13294, 1, 4, '2025-10-09', '07:00:00', 0, 2),
(13295, 1, 4, '2025-10-07', '06:00:00', 0, 1),
(13296, 1, 4, '2025-10-06', '06:00:00', 0, 1),
(13297, 1, 4, '2025-10-03', '06:00:00', 0, 1),
(13298, 1, 4, '2025-10-01', '07:00:00', 0, 2),
(13299, 1, 1, '2025-10-09', '11:30:00', 0, 4),
(13300, 1, 4, '2025-10-09', '09:00:00', 0, 3),
(13301, 4, 4, '2025-10-10', '21:00:00', 0, 11),
(13302, 7, 1, '2025-10-10', '07:00:00', 0, 14),
(13303, 1, 4, '2025-10-21', '06:00:00', 0, 1),
(13304, 1, 4, '2025-10-22', '06:00:00', 0, 1),
(13305, 1, 4, '2025-10-24', '06:00:00', 0, 1),
(13306, 1, 4, '2025-10-27', '06:00:00', 0, 1),
(13307, 1, 4, '2025-10-28', '06:00:00', 0, 1),
(13308, 1, 4, '2025-11-01', '06:00:00', 0, 1),
(13309, 1, 4, '2025-11-30', '06:00:00', 0, 1),
(13310, 1, 4, '2025-11-28', '06:00:00', 0, 1),
(13311, 1, 4, '2025-11-27', '06:00:00', 0, 1),
(13312, 1, 4, '2025-11-26', '06:00:00', 0, 1),
(13313, 1, 4, '2025-11-20', '06:00:00', 0, 1),
(13314, 1, 4, '2025-11-21', '06:00:00', 0, 1),
(13315, 1, 4, '2025-11-19', '06:00:00', 0, 1),
(13316, 1, 4, '2025-11-18', '06:00:00', 0, 1),
(13317, 1, 4, '2025-11-25', '06:00:00', 0, 1),
(13318, 1, 4, '2025-11-29', '06:00:00', 0, 1),
(13319, 1, 4, '2025-11-23', '06:00:00', 0, 1),
(13320, 1, 4, '2025-11-16', '06:00:00', 0, 1),
(13321, 1, 4, '2025-11-13', '06:00:00', 0, 1),
(13322, 1, 4, '2025-11-24', '06:00:00', 0, 1),
(13323, 1, 4, '2025-11-08', '06:00:00', 0, 1),
(13324, 1, 4, '2025-11-09', '06:00:00', 0, 1),
(13325, 1, 4, '2025-11-28', '07:00:00', 0, 2),
(13326, 1, 4, '2025-11-28', '09:00:00', 0, 3),
(13327, 1, 1, '2025-11-28', '11:30:00', 0, 4),
(13328, 1, 4, '2025-11-28', '13:30:00', 0, 5),
(13329, 7, 1, '2025-11-28', '07:00:00', 0, 14),
(13330, 7, 1, '2025-11-27', '07:00:00', 0, 14),
(13331, 7, 1, '2025-11-13', '07:00:00', 0, 14),
(13332, 1, 4, '2025-11-14', '06:00:00', 0, 1),
(14247, 1, 4, '2025-10-19', '07:00:00', 0, 2),
(14249, 1, 4, '2025-10-19', '09:00:00', 0, 3),
(14251, 1, 1, '2025-10-19', '11:30:00', 0, 4),
(14253, 1, 4, '2025-10-19', '13:30:00', 0, 5),
(14255, 1, 4, '2025-10-19', '15:30:00', 0, 6),
(14257, 1, 1, '2025-10-19', '17:00:00', 0, 7),
(14259, 1, 1, '2025-10-19', '19:00:00', 0, 8),
(14261, 2, 1, '2025-10-19', '08:00:00', 0, 9),
(14263, 3, 1, '2025-10-19', '08:00:00', 0, 10),
(14265, 4, 4, '2025-10-19', '21:00:00', 0, 11),
(14267, 5, 1, '2025-10-19', '16:00:00', 0, 12),
(14269, 6, 4, '2025-10-19', '14:00:00', 0, 13),
(14271, 7, 1, '2025-10-19', '07:00:00', 0, 14),
(14273, 7, 4, '2025-10-19', '10:00:00', 0, 15),
(14275, 7, 4, '2025-10-19', '12:00:00', 0, 16),
(14277, 7, 1, '2025-10-19', '13:00:00', 0, 17),
(14279, 7, 4, '2025-10-19', '14:00:00', 0, 18),
(14281, 7, 1, '2025-10-19', '15:00:00', 0, 19),
(14283, 7, 4, '2025-10-19', '17:00:00', 0, 20),
(14285, 7, 4, '2025-10-19', '19:00:00', 0, 21),
(14287, 8, 1, '2025-10-19', '16:00:00', 0, 22),
(14289, 9, 1, '2025-10-19', '07:00:00', 0, 23),
(14291, 10, 1, '2025-10-19', '11:00:00', 0, 24),
(14293, 1, 4, '2025-10-20', '06:00:00', 0, 1),
(14295, 1, 4, '2025-10-20', '07:00:00', 0, 2),
(14297, 1, 4, '2025-10-20', '09:00:00', 0, 3),
(14299, 1, 1, '2025-10-20', '11:30:00', 0, 4),
(14301, 1, 4, '2025-10-20', '13:30:00', 0, 5),
(14303, 1, 4, '2025-10-20', '15:30:00', 0, 6),
(14305, 1, 1, '2025-10-20', '17:00:00', 0, 7),
(14307, 1, 1, '2025-10-20', '19:00:00', 0, 8),
(14309, 2, 1, '2025-10-20', '08:00:00', 0, 9),
(14311, 3, 1, '2025-10-20', '08:00:00', 0, 10),
(14313, 4, 4, '2025-10-20', '21:00:00', 0, 11),
(14315, 5, 1, '2025-10-20', '16:00:00', 0, 12),
(14317, 6, 4, '2025-10-20', '14:00:00', 0, 13),
(14319, 7, 1, '2025-10-20', '07:00:00', 0, 14),
(14321, 7, 4, '2025-10-20', '10:00:00', 0, 15),
(14323, 7, 4, '2025-10-20', '12:00:00', 0, 16),
(14325, 7, 1, '2025-10-20', '13:00:00', 0, 17),
(14327, 7, 4, '2025-10-20', '14:00:00', 0, 18),
(14329, 7, 1, '2025-10-20', '15:00:00', 0, 19),
(14331, 7, 4, '2025-10-20', '17:00:00', 0, 20),
(14333, 7, 4, '2025-10-20', '19:00:00', 0, 21),
(14335, 8, 1, '2025-10-20', '16:00:00', 0, 22),
(14337, 9, 1, '2025-10-20', '07:00:00', 0, 23),
(14339, 10, 1, '2025-10-20', '11:00:00', 0, 24);

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

INSERT INTO `trip_vehicles` (`id`, `trip_id`, `vehicle_id`, `is_primary`) VALUES
(1, 1, 4, 1),
(3, 2, 5, 1),
(4, 3, 4, 1),
(5, 4, 3, 1),
(6, 5, 4, 1),
(7, 6, 4, 1),
(8, 7, 1, 1),
(9, 8, 1, 1),
(10, 9, 1, 1),
(11, 10, 1, 1),
(12, 11, 4, 1),
(13, 12, 1, 1),
(14, 13, 4, 1),
(15, 14, 1, 1),
(16, 15, 4, 1),
(17, 16, 4, 1),
(18, 17, 1, 1),
(19, 18, 4, 1),
(20, 19, 1, 1),
(21, 20, 4, 1),
(22, 21, 4, 1),
(23, 22, 1, 1),
(24, 23, 1, 1),
(25, 24, 1, 1),
(26, 25, 4, 1),
(27, 26, 4, 1),
(28, 27, 4, 1),
(29, 28, 1, 1),
(30, 29, 4, 1),
(31, 30, 4, 1),
(32, 31, 1, 1),
(33, 32, 1, 1),
(34, 33, 1, 1),
(35, 34, 1, 1),
(36, 35, 4, 1),
(37, 36, 1, 1),
(38, 37, 4, 1),
(39, 38, 1, 1),
(40, 39, 4, 1),
(41, 40, 4, 1),
(42, 41, 1, 1),
(43, 42, 4, 1),
(44, 43, 1, 1),
(45, 44, 4, 1),
(46, 45, 4, 1),
(47, 46, 1, 1),
(48, 47, 1, 1),
(49, 48, 1, 1),
(50, 49, 4, 1),
(51, 50, 4, 1),
(52, 51, 4, 1),
(53, 52, 1, 1),
(54, 53, 4, 1),
(55, 54, 4, 1),
(56, 55, 1, 1),
(57, 56, 1, 1),
(58, 57, 1, 1),
(59, 58, 1, 1),
(60, 59, 4, 1),
(61, 60, 1, 1),
(62, 61, 4, 1),
(63, 62, 1, 1),
(64, 63, 4, 1),
(65, 64, 4, 1),
(66, 65, 1, 1),
(67, 66, 4, 1),
(68, 67, 1, 1),
(69, 68, 4, 1),
(70, 69, 4, 1),
(71, 70, 1, 1),
(72, 71, 1, 1),
(73, 72, 1, 1),
(74, 73, 4, 1),
(75, 74, 4, 1),
(76, 75, 4, 1),
(77, 76, 1, 1),
(78, 77, 4, 1),
(79, 78, 4, 1),
(80, 79, 1, 1),
(81, 80, 1, 1),
(82, 81, 1, 1),
(83, 82, 1, 1),
(84, 83, 4, 1),
(85, 84, 1, 1),
(86, 85, 4, 1),
(87, 86, 1, 1),
(88, 87, 4, 1),
(89, 88, 4, 1),
(90, 89, 1, 1),
(91, 90, 4, 1),
(92, 91, 1, 1),
(93, 92, 4, 1),
(94, 93, 4, 1),
(95, 94, 1, 1),
(96, 95, 1, 1),
(97, 96, 1, 1),
(98, 97, 4, 1),
(99, 98, 4, 1),
(100, 99, 4, 1),
(101, 100, 1, 1),
(102, 101, 4, 1),
(103, 102, 4, 1),
(104, 103, 1, 1),
(105, 104, 1, 1),
(106, 105, 1, 1),
(107, 106, 1, 1),
(108, 107, 4, 1),
(109, 108, 1, 1),
(110, 109, 4, 1),
(111, 110, 1, 1),
(112, 111, 4, 1),
(113, 112, 4, 1),
(114, 113, 1, 1),
(115, 114, 4, 1),
(116, 115, 1, 1),
(117, 116, 4, 1),
(118, 117, 4, 1),
(119, 118, 1, 1),
(120, 119, 1, 1),
(121, 120, 1, 1),
(122, 121, 4, 1),
(123, 122, 4, 1),
(124, 123, 4, 1),
(125, 124, 1, 1),
(126, 125, 4, 1),
(127, 126, 4, 1),
(128, 127, 1, 1),
(129, 128, 1, 1),
(130, 129, 1, 1),
(131, 130, 1, 1),
(132, 131, 4, 1),
(133, 132, 1, 1),
(134, 133, 4, 1),
(135, 134, 1, 1),
(136, 135, 4, 1),
(137, 136, 4, 1),
(138, 137, 1, 1),
(139, 138, 4, 1),
(140, 139, 1, 1),
(141, 140, 4, 1),
(142, 141, 4, 1),
(143, 142, 1, 1),
(144, 143, 1, 1),
(145, 144, 1, 1),
(146, 145, 4, 1),
(147, 146, 4, 1),
(148, 147, 4, 1),
(149, 148, 1, 1),
(150, 149, 4, 1),
(151, 150, 4, 1),
(152, 151, 1, 1),
(153, 152, 1, 1),
(154, 153, 1, 1),
(155, 154, 1, 1),
(156, 155, 4, 1),
(157, 156, 1, 1),
(158, 157, 4, 1),
(159, 158, 1, 1),
(160, 159, 4, 1),
(161, 160, 4, 1),
(162, 161, 1, 1),
(163, 162, 4, 1),
(164, 163, 1, 1),
(165, 164, 4, 1),
(166, 165, 4, 1),
(167, 166, 1, 1),
(168, 167, 1, 1),
(169, 168, 1, 1),
(10922, 10921, 4, 1),
(10923, 10922, 1, 1),
(10924, 10923, 1, 1),
(10925, 10924, 4, 1),
(10926, 10925, 4, 1),
(11142, 11138, 4, 1),
(11145, 11142, 4, 1),
(11148, 11144, 4, 1),
(11150, 11147, 1, 1),
(11152, 11149, 4, 1),
(11154, 11151, 4, 1),
(11157, 11154, 1, 1),
(11159, 11156, 1, 1),
(11162, 11159, 1, 1),
(11164, 11161, 1, 1),
(11167, 11163, 4, 1),
(11169, 11166, 1, 1),
(11172, 11168, 4, 1),
(11174, 11171, 1, 1),
(11177, 11173, 4, 1),
(11179, 11176, 4, 1),
(11181, 11178, 1, 1),
(11184, 11181, 4, 1),
(11187, 11183, 1, 1),
(11189, 11185, 4, 1),
(11191, 11188, 4, 1),
(11194, 11190, 1, 1),
(11197, 11193, 1, 1),
(11199, 11196, 1, 1),
(11266, 11262, 4, 1),
(11267, 11263, 4, 1),
(11604, 11600, 4, 1),
(11605, 11601, 1, 1),
(11606, 11602, 1, 1),
(11607, 11603, 4, 1),
(11608, 11604, 4, 1),
(11609, 11605, 4, 1),
(13290, 13286, 1, 1),
(13291, 13287, 4, 1),
(13292, 13288, 1, 1),
(13293, 13289, 4, 1),
(13294, 13290, 4, 1),
(13295, 13291, 4, 1),
(13296, 13292, 4, 1),
(13297, 13293, 4, 1),
(13298, 13294, 4, 1),
(13299, 13295, 4, 1),
(13300, 13296, 4, 1),
(13301, 13297, 4, 1),
(13302, 13298, 4, 1),
(13303, 13299, 1, 1),
(13304, 13300, 4, 1),
(13305, 13301, 4, 1),
(13306, 13302, 1, 1),
(13307, 13303, 4, 1),
(13308, 13304, 4, 1),
(13309, 13305, 4, 1),
(13310, 13306, 4, 1),
(13311, 13307, 4, 1),
(13312, 13308, 4, 1),
(13313, 13309, 4, 1),
(13314, 13310, 4, 1),
(13315, 13311, 4, 1),
(13316, 13312, 4, 1),
(13317, 13313, 4, 1),
(13318, 13314, 4, 1),
(13319, 13315, 4, 1),
(13320, 13316, 4, 1),
(13321, 13317, 4, 1),
(13322, 13318, 4, 1),
(13323, 13319, 4, 1),
(13324, 13320, 4, 1),
(13325, 13321, 4, 1),
(13326, 13322, 4, 1),
(13327, 13323, 4, 1),
(13328, 13324, 4, 1),
(13329, 13325, 4, 1),
(13330, 13326, 4, 1),
(13331, 13327, 1, 1),
(13332, 13328, 4, 1),
(13333, 13329, 1, 1),
(13334, 13330, 1, 1),
(13335, 13331, 1, 1),
(13336, 13332, 4, 1),
(14251, 14247, 4, 1),
(14253, 14249, 4, 1),
(14255, 14251, 1, 1),
(14257, 14253, 4, 1),
(14259, 14255, 4, 1),
(14261, 14257, 1, 1),
(14263, 14259, 1, 1),
(14265, 14261, 1, 1),
(14267, 14263, 1, 1),
(14269, 14265, 4, 1),
(14271, 14267, 1, 1),
(14273, 14269, 4, 1),
(14275, 14271, 1, 1),
(14277, 14273, 4, 1),
(14279, 14275, 4, 1),
(14281, 14277, 1, 1),
(14283, 14279, 4, 1),
(14285, 14281, 1, 1),
(14287, 14283, 4, 1),
(14289, 14285, 4, 1),
(14291, 14287, 1, 1),
(14293, 14289, 1, 1),
(14295, 14291, 1, 1),
(14297, 14293, 4, 1),
(14299, 14295, 4, 1),
(14301, 14297, 4, 1),
(14303, 14299, 1, 1),
(14305, 14301, 4, 1),
(14307, 14303, 4, 1),
(14309, 14305, 1, 1),
(14311, 14307, 1, 1),
(14313, 14309, 1, 1),
(14315, 14311, 1, 1),
(14317, 14313, 4, 1),
(14319, 14315, 1, 1),
(14321, 14317, 4, 1),
(14323, 14319, 1, 1),
(14325, 14321, 4, 1),
(14327, 14323, 4, 1),
(14329, 14325, 1, 1),
(14331, 14327, 4, 1),
(14333, 14329, 1, 1),
(14335, 14331, 4, 1),
(14337, 14333, 4, 1),
(14339, 14335, 1, 1),
(14341, 14337, 1, 1),
(14343, 14339, 1, 1);

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

INSERT INTO `trip_vehicle_employees` (`id`, `trip_vehicle_id`, `employee_id`) VALUES
(1, 15, 9),
(2, 18, 8);

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

INSERT INTO `vehicles` (`id`, `name`, `seat_count`, `type`, `plate_number`, `operator_id`) VALUES
(1, 'Microbuz 20 locuri', 20, 'microbuz', 'BT22DMS', 2),
(2, 'Autocar Scania', 50, 'autocar', 'IS33DMS', 2),
(3, 'Autocar Mercedes', 51, 'autocar', 'BT21DMS', 2),
(4, 'Microbuz', 20, 'microbuz', 'BT01PRI', 1),
(5, 'Microbuz', 20, 'microbuz', 'BT02PRI', 1);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `agencies`
--
ALTER TABLE `agencies`
  ADD PRIMARY KEY (`id`);

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
  ADD PRIMARY KEY (`id`);

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
-- Indexes for table `reservations`
--
ALTER TABLE `reservations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `reservations_backup`
--
ALTER TABLE `reservations_backup`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `reservation_discounts`
--
ALTER TABLE `reservation_discounts`
  ADD PRIMARY KEY (`id`);

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
  ADD PRIMARY KEY (`id`);

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
-- AUTO_INCREMENT for table `blacklist`
--
ALTER TABLE `blacklist`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

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
-- AUTO_INCREMENT for table `no_shows`
--
ALTER TABLE `no_shows`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

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
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=36;

--
-- AUTO_INCREMENT for table `price_lists`
--
ALTER TABLE `price_lists`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `price_list_items`
--
ALTER TABLE `price_list_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `pricing_categories`
--
ALTER TABLE `pricing_categories`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `reservations`
--
ALTER TABLE `reservations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=41;

--
-- AUTO_INCREMENT for table `reservations_backup`
--
ALTER TABLE `reservations_backup`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `reservation_discounts`
--
ALTER TABLE `reservation_discounts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

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
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=280;

--
-- AUTO_INCREMENT for table `stations`
--
ALTER TABLE `stations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT for table `traveler_defaults`
--
ALTER TABLE `traveler_defaults`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `trips`
--
ALTER TABLE `trips`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14341;

--
-- AUTO_INCREMENT for table `trip_vehicles`
--
ALTER TABLE `trip_vehicles`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14345;

--
-- AUTO_INCREMENT for table `trip_vehicle_employees`
--
ALTER TABLE `trip_vehicle_employees`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `vehicles`
--
ALTER TABLE `vehicles`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `schedule_exceptions`
--
ALTER TABLE `schedule_exceptions`
  ADD CONSTRAINT `fk_se_schedule` FOREIGN KEY (`schedule_id`) REFERENCES `route_schedules` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
