-- Create Django application user
CREATE USER 'PIES_User'@'localhost'
IDENTIFIED BY 'pies1234';

-- Grant CRUD and stored procedure permissions
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE
ON unidb.*
TO 'PIES_User'@'localhost';

-- Verify permissions
SHOW GRANTS FOR 'PIES_User'@'localhost';
