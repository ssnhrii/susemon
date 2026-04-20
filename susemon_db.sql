-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Apr 19, 2026 at 06:46 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `susemon_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `ai_predictions`
--

CREATE TABLE `ai_predictions` (
  `id` int(11) NOT NULL,
  `node_id` varchar(10) NOT NULL,
  `prediction_type` varchar(50) NOT NULL,
  `confidence` decimal(5,2) NOT NULL,
  `predicted_value` decimal(5,2) DEFAULT NULL,
  `prediction_time` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ai_predictions`
--

INSERT INTO `ai_predictions` (`id`, `node_id`, `prediction_type`, `confidence`, `predicted_value`, `prediction_time`, `created_at`) VALUES
(1, 'D4', 'temperature', 91.00, 41.80, '2026-04-18 20:26:55', '2026-04-18 19:56:55');

-- --------------------------------------------------------

--
-- Table structure for table `notifications`
--

CREATE TABLE `notifications` (
  `id` int(11) NOT NULL,
  `node_id` varchar(10) DEFAULT NULL,
  `title` varchar(200) NOT NULL,
  `message` text NOT NULL,
  `type` enum('critical','warning','success','info') NOT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `notifications`
--

INSERT INTO `notifications` (`id`, `node_id`, `title`, `message`, `type`, `is_read`, `created_at`) VALUES
(1, 'D4', 'Suhu Kritis - Node D4', 'Suhu mencapai 41.2°C pada Rack Storage. Tindakan segera diperlukan!', 'critical', 0, '2026-04-18 19:47:14'),
(2, 'B2', 'Anomali Terdeteksi', 'Pola anomali suhu tidak normal pada Node B2. AI confidence: 87%', 'warning', 0, '2026-04-18 19:47:14'),
(3, 'D4', 'Prediksi Overheating', 'AI memprediksi overheating dalam 30 menit pada Node D4', 'warning', 0, '2026-04-18 19:47:14'),
(4, NULL, 'Koneksi LoRa Berhasil', 'Semua node sensor terhubung dengan gateway. Signal strength: Excellent', 'success', 0, '2026-04-18 19:47:14');

-- --------------------------------------------------------

--
-- Table structure for table `sensor_data`
--

CREATE TABLE `sensor_data` (
  `id` int(11) NOT NULL,
  `node_id` varchar(10) NOT NULL,
  `temperature` decimal(5,2) NOT NULL,
  `humidity` decimal(5,2) NOT NULL,
  `status` enum('AMAN','WASPADA','BERBAHAYA') NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `sensor_data`
--

INSERT INTO `sensor_data` (`id`, `node_id`, `temperature`, `humidity`, `status`, `timestamp`) VALUES
(1, 'A1', 26.65, 70.10, 'AMAN', '2026-04-18 19:47:14'),
(2, 'A1', 27.95, 61.53, 'AMAN', '2026-04-18 19:17:14'),
(3, 'A1', 27.54, 67.36, 'AMAN', '2026-04-18 18:47:14'),
(4, 'A1', 30.20, 62.73, 'AMAN', '2026-04-18 18:17:14'),
(5, 'A1', 27.36, 66.32, 'AMAN', '2026-04-18 17:47:14'),
(6, 'A1', 27.41, 60.27, 'AMAN', '2026-04-18 17:17:14'),
(7, 'A1', 27.86, 79.91, 'AMAN', '2026-04-18 16:47:14'),
(8, 'A1', 28.02, 61.66, 'AMAN', '2026-04-18 16:17:14'),
(9, 'A1', 26.52, 75.27, 'AMAN', '2026-04-18 15:47:14'),
(10, 'A1', 27.21, 75.80, 'AMAN', '2026-04-18 15:17:14'),
(11, 'A1', 28.56, 69.71, 'AMAN', '2026-04-18 14:47:14'),
(12, 'A1', 28.37, 67.53, 'AMAN', '2026-04-18 14:17:14'),
(13, 'A1', 29.20, 77.95, 'AMAN', '2026-04-18 13:47:14'),
(14, 'A1', 29.67, 72.47, 'AMAN', '2026-04-18 13:17:14'),
(15, 'A1', 29.48, 76.57, 'AMAN', '2026-04-18 12:47:14'),
(16, 'A1', 29.35, 60.55, 'AMAN', '2026-04-18 12:17:14'),
(17, 'A1', 29.47, 61.77, 'AMAN', '2026-04-18 11:47:14'),
(18, 'A1', 27.57, 78.69, 'AMAN', '2026-04-18 11:17:14'),
(19, 'A1', 27.50, 72.60, 'AMAN', '2026-04-18 10:47:14'),
(20, 'A1', 29.55, 70.69, 'AMAN', '2026-04-18 10:17:14'),
(21, 'B2', 31.66, 68.58, 'AMAN', '2026-04-18 19:47:14'),
(22, 'B2', 30.51, 77.38, 'AMAN', '2026-04-18 19:17:14'),
(23, 'B2', 31.33, 69.79, 'AMAN', '2026-04-18 18:47:14'),
(24, 'B2', 33.05, 77.13, 'AMAN', '2026-04-18 18:17:14'),
(25, 'B2', 33.65, 74.63, 'AMAN', '2026-04-18 17:47:14'),
(26, 'B2', 33.97, 69.81, 'AMAN', '2026-04-18 17:17:14'),
(27, 'B2', 31.32, 78.00, 'AMAN', '2026-04-18 16:47:14'),
(28, 'B2', 32.68, 60.86, 'AMAN', '2026-04-18 16:17:14'),
(29, 'B2', 31.51, 67.80, 'AMAN', '2026-04-18 15:47:14'),
(30, 'B2', 30.58, 66.58, 'AMAN', '2026-04-18 15:17:14'),
(31, 'B2', 32.90, 70.58, 'AMAN', '2026-04-18 14:47:14'),
(32, 'B2', 31.50, 75.22, 'AMAN', '2026-04-18 14:17:14'),
(33, 'B2', 31.46, 65.59, 'AMAN', '2026-04-18 13:47:14'),
(34, 'B2', 32.33, 72.60, 'AMAN', '2026-04-18 13:17:14'),
(35, 'B2', 33.43, 79.23, 'AMAN', '2026-04-18 12:47:14'),
(36, 'B2', 32.69, 62.25, 'AMAN', '2026-04-18 12:17:14'),
(37, 'B2', 32.40, 77.31, 'AMAN', '2026-04-18 11:47:14'),
(38, 'B2', 31.31, 66.65, 'AMAN', '2026-04-18 11:17:14'),
(39, 'B2', 31.87, 72.32, 'AMAN', '2026-04-18 10:47:14'),
(40, 'B2', 32.60, 75.54, 'AMAN', '2026-04-18 10:17:14'),
(41, 'C3', 25.68, 79.34, 'AMAN', '2026-04-18 19:47:14'),
(42, 'C3', 26.37, 76.75, 'AMAN', '2026-04-18 19:17:14'),
(43, 'C3', 28.66, 75.24, 'AMAN', '2026-04-18 18:47:14'),
(44, 'C3', 28.40, 77.80, 'AMAN', '2026-04-18 18:17:14'),
(45, 'C3', 26.52, 66.34, 'AMAN', '2026-04-18 17:47:14'),
(46, 'C3', 27.01, 70.94, 'AMAN', '2026-04-18 17:17:14'),
(47, 'C3', 25.99, 77.04, 'AMAN', '2026-04-18 16:47:14'),
(48, 'C3', 26.97, 65.22, 'AMAN', '2026-04-18 16:17:14'),
(49, 'C3', 27.50, 66.06, 'AMAN', '2026-04-18 15:47:14'),
(50, 'C3', 28.14, 74.73, 'AMAN', '2026-04-18 15:17:14'),
(51, 'C3', 25.00, 73.36, 'AMAN', '2026-04-18 14:47:14'),
(52, 'C3', 28.45, 65.02, 'AMAN', '2026-04-18 14:17:14'),
(53, 'C3', 24.94, 69.31, 'AMAN', '2026-04-18 13:47:14'),
(54, 'C3', 25.86, 76.30, 'AMAN', '2026-04-18 13:17:14'),
(55, 'C3', 28.26, 67.38, 'AMAN', '2026-04-18 12:47:14'),
(56, 'C3', 28.20, 79.41, 'AMAN', '2026-04-18 12:17:14'),
(57, 'C3', 25.27, 73.31, 'AMAN', '2026-04-18 11:47:14'),
(58, 'C3', 25.58, 67.74, 'AMAN', '2026-04-18 11:17:14'),
(59, 'C3', 26.03, 71.86, 'AMAN', '2026-04-18 10:47:14'),
(60, 'C3', 25.35, 66.26, 'AMAN', '2026-04-18 10:17:14'),
(61, 'D4', 42.08, 63.03, 'BERBAHAYA', '2026-04-18 19:47:14'),
(62, 'D4', 42.04, 67.51, 'BERBAHAYA', '2026-04-18 19:17:14'),
(63, 'D4', 39.35, 67.90, 'WASPADA', '2026-04-18 18:47:14'),
(64, 'D4', 39.85, 61.67, 'WASPADA', '2026-04-18 18:17:14'),
(65, 'D4', 39.78, 67.66, 'WASPADA', '2026-04-18 17:47:14'),
(66, 'D4', 39.56, 70.89, 'WASPADA', '2026-04-18 17:17:14'),
(67, 'D4', 42.54, 76.13, 'BERBAHAYA', '2026-04-18 16:47:14'),
(68, 'D4', 41.85, 78.28, 'BERBAHAYA', '2026-04-18 16:17:14'),
(69, 'D4', 41.50, 72.57, 'BERBAHAYA', '2026-04-18 15:47:14'),
(70, 'D4', 42.55, 74.63, 'BERBAHAYA', '2026-04-18 15:17:14'),
(71, 'D4', 39.81, 67.34, 'WASPADA', '2026-04-18 14:47:14'),
(72, 'D4', 40.89, 70.64, 'BERBAHAYA', '2026-04-18 14:17:14'),
(73, 'D4', 40.36, 78.39, 'BERBAHAYA', '2026-04-18 13:47:14'),
(74, 'D4', 41.68, 60.05, 'BERBAHAYA', '2026-04-18 13:17:14'),
(75, 'D4', 39.90, 70.20, 'WASPADA', '2026-04-18 12:47:14'),
(76, 'D4', 40.35, 74.22, 'BERBAHAYA', '2026-04-18 12:17:14'),
(77, 'D4', 42.17, 63.27, 'BERBAHAYA', '2026-04-18 11:47:14'),
(78, 'D4', 41.02, 61.18, 'BERBAHAYA', '2026-04-18 11:17:14'),
(79, 'D4', 41.81, 73.19, 'BERBAHAYA', '2026-04-18 10:47:14'),
(80, 'D4', 43.17, 70.59, 'BERBAHAYA', '2026-04-18 10:17:14');

-- --------------------------------------------------------

--
-- Table structure for table `sensor_nodes`
--

CREATE TABLE `sensor_nodes` (
  `id` int(11) NOT NULL,
  `node_id` varchar(10) NOT NULL,
  `node_name` varchar(100) NOT NULL,
  `location` varchar(200) NOT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `sensor_nodes`
--

INSERT INTO `sensor_nodes` (`id`, `node_id`, `node_name`, `location`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 'A1', 'Node Sensor A1', 'Rack Server Utama', 1, '2026-04-18 19:47:14', '2026-04-18 19:47:14'),
(2, 'B2', 'Node Sensor B2', 'Rack Server Backup', 1, '2026-04-18 19:47:14', '2026-04-18 19:47:14'),
(3, 'C3', 'Node Sensor C3', 'Rack Network', 1, '2026-04-18 19:47:14', '2026-04-18 19:47:14'),
(4, 'D4', 'Node Sensor D4', 'Rack Storage', 1, '2026-04-18 19:47:14', '2026-04-18 19:47:14');

-- --------------------------------------------------------

--
-- Table structure for table `system_logs`
--

CREATE TABLE `system_logs` (
  `id` int(11) NOT NULL,
  `log_type` varchar(50) NOT NULL,
  `message` text NOT NULL,
  `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`metadata`)),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `ip_address` varchar(50) NOT NULL,
  `access_code` varchar(255) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_login` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `ip_address`, `access_code`, `name`, `created_at`, `last_login`) VALUES
(1, '127.0.0.1', 'ADMIN123', 'Admin Local', '2026-04-18 19:47:14', '2026-04-18 19:56:55'),
(2, '192.168.1.100', 'SUSEMON2026', 'Admin Network', '2026-04-18 19:47:14', NULL);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `ai_predictions`
--
ALTER TABLE `ai_predictions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_node_time` (`node_id`,`prediction_time`);

--
-- Indexes for table `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `node_id` (`node_id`),
  ADD KEY `idx_created` (`created_at`);

--
-- Indexes for table `sensor_data`
--
ALTER TABLE `sensor_data`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_node_timestamp` (`node_id`,`timestamp`),
  ADD KEY `idx_timestamp` (`timestamp`);

--
-- Indexes for table `sensor_nodes`
--
ALTER TABLE `sensor_nodes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `node_id` (`node_id`);

--
-- Indexes for table `system_logs`
--
ALTER TABLE `system_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_type_created` (`log_type`,`created_at`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ip_address` (`ip_address`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `ai_predictions`
--
ALTER TABLE `ai_predictions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `sensor_data`
--
ALTER TABLE `sensor_data`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=81;

--
-- AUTO_INCREMENT for table `sensor_nodes`
--
ALTER TABLE `sensor_nodes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `system_logs`
--
ALTER TABLE `system_logs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `ai_predictions`
--
ALTER TABLE `ai_predictions`
  ADD CONSTRAINT `ai_predictions_ibfk_1` FOREIGN KEY (`node_id`) REFERENCES `sensor_nodes` (`node_id`) ON DELETE CASCADE;

--
-- Constraints for table `notifications`
--
ALTER TABLE `notifications`
  ADD CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`node_id`) REFERENCES `sensor_nodes` (`node_id`) ON DELETE SET NULL;

--
-- Constraints for table `sensor_data`
--
ALTER TABLE `sensor_data`
  ADD CONSTRAINT `sensor_data_ibfk_1` FOREIGN KEY (`node_id`) REFERENCES `sensor_nodes` (`node_id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
