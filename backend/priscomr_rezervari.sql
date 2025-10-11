-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: db:3306
-- Generation Time: Oct 10, 2025 at 08:42 PM
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

-- --------------------------------------------------------

--
-- Table structure for table `people`
--

CREATE TABLE `people` (
  `id` int(11) NOT NULL,
  `name` text NOT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `blacklist` tinyint(1) NOT NULL DEFAULT 0,
  `whitelist` tinyint(1) NOT NULL DEFAULT 0,
  `notes` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
(8, 2, 7, 1, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(9, 2, 8, 2, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(10, 2, 10, 3, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(11, 2, 6, 4, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(16, 4, 8, 1, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(17, 4, 2, 2, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(18, 4, 3, 3, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(19, 5, 4, 1, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(20, 5, 15, 2, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(21, 5, 1, 3, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(22, 5, 8, 4, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00'),
(23, 6, 3, 1, NULL, NULL, 0, 'circle', 200.00, NULL, '2025-09-23 20:49:00', '2025-09-23 20:49:00');

-- --------------------------------------------------------

--
-- Table structure for table `schedule_exceptions`
--

CREATE TABLE `schedule_exceptions` (
  `id` int(11) NOT NULL,
  `route_schedule_id` int(11) NOT NULL,
  `date` date NOT NULL,
  `exception_type` enum('added','removed') NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
(15, 'Bacău', 'Bacău', NULL, 46.54266484, 26.92362785, '2025-09-23 20:49:00', '2025-10-04 12:22:20');

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
  `disabled` tinyint(1) DEFAULT 0,
  `route_schedule_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `trip_vehicles`
--

CREATE TABLE `trip_vehicles` (
  `id` int(11) NOT NULL,
  `trip_id` int(11) DEFAULT NULL,
  `vehicle_id` int(11) DEFAULT NULL,
  `is_primary` tinyint(1) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `trip_vehicle_employees`
--

CREATE TABLE `trip_vehicle_employees` (
  `id` int(11) NOT NULL,
  `trip_vehicle_id` int(11) DEFAULT NULL,
  `employee_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
  ADD PRIMARY KEY (`id`);

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
  ADD PRIMARY KEY (`id`);

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
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `trip_vehicles`
--
ALTER TABLE `trip_vehicles`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `trip_vehicle_employees`
--
ALTER TABLE `trip_vehicle_employees`
  ADD PRIMARY KEY (`id`);

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
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

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
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `operators`
--
ALTER TABLE `operators`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `payments`
--
ALTER TABLE `payments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `people`
--
ALTER TABLE `people`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `price_list_items`
--
ALTER TABLE `price_list_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `reservation_discounts`
--
ALTER TABLE `reservation_discounts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `schedule_exceptions`
--
ALTER TABLE `schedule_exceptions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
