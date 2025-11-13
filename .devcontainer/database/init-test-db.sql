-- Initialize test database for CRITDB testing
-- This script creates the necessary databases and user permissions

-- Create test user
CREATE USER IF NOT EXISTS 'test'@'%' IDENTIFIED BY 'test';

-- Create the main "default" database to keep Laravel happy
CREATE DATABASE IF NOT EXISTS test;

-- Create customer-specific databases (these will be used by Service tests)
-- Customer ID 123 -> cdabdab2669c0082
CREATE DATABASE IF NOT EXISTS cdabdab2669c0082;
-- Customer ID 456 -> cd9820281530e613
CREATE DATABASE IF NOT EXISTS cd9820281530e613;

-- These are unused, but the Laravel connection requires a database name on init
-- Create critdb database to simulate a different database like production
CREATE DATABASE IF NOT EXISTS critdb;
-- Create slowpoke database to simulate a different database like production
CREATE DATABASE IF NOT EXISTS slowpoke;
-- Create catdb database to simulate a different database like production
CREATE DATABASE IF NOT EXISTS catdb;

-- Grant full permissions to test user (it's a local test DB)
GRANT ALL PRIVILEGES ON *.* TO 'test'@'%' WITH GRANT OPTION;

-- Flush privileges to apply changes
FLUSH PRIVILEGES;
