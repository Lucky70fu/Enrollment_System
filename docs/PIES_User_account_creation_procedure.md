# Step-by-Step Procedure: Creating the `PIES_User` MySQL Account

This procedure creates the MySQL account that the Django PIES project
will use to connect to the `unidb` database.

## Account details

  Setting           Value
  ----------------- -------------
  MySQL username    `PIES_User`
  MySQL host        `localhost`
  Password          `pies1234`
  Database/schema   `unidb`
  MySQL port        `3306`

> **Important:** The account `'PIES_User'@'localhost'` can connect only
> from the same machine on which MySQL is running. This matches a setup
> where Django and MySQL run on the same computer.

## Step 1: Open a terminal

Open Command Prompt, PowerShell, or a terminal on the computer running
MySQL.

## Step 2: Log in to MySQL as an administrator

Run:

``` bash
mysql -u root -p
```

Enter the MySQL administrator password when prompted.

You need an account with permission to create users and grant
privileges.

## Step 3: Confirm that `unidb` exists

At the MySQL prompt, run:

``` sql
SHOW DATABASES;
```

Check that `unidb` appears in the results.

If the schema has not been created yet, create it (only if you are
responsible for creating it):

``` sql
CREATE DATABASE unidb;
```

## Step 4: Create the PIES account

Execute:

``` sql
CREATE USER 'PIES_User'@'localhost'
IDENTIFIED BY 'pies1234';
```

This creates a MySQL account named `PIES_User`, with `localhost` as its
permitted connection host.

If MySQL reports that the account already exists, do not run
`CREATE USER` again. You can inspect the account or reset its password
with:

``` sql
ALTER USER 'PIES_User'@'localhost'
IDENTIFIED BY 'pies1234';
```

## Step 5: Grant permissions on `unidb`

Execute:

``` sql
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE
ON unidb.*
TO 'PIES_User'@'localhost';
```

These privileges allow the Django application to:

-   `SELECT`: retrieve records.
-   `INSERT`: add records.
-   `UPDATE`: modify records.
-   `DELETE`: remove records.
-   `EXECUTE`: call stored procedures and functions.

The grant applies to objects in `unidb`, not every database on the MySQL
server.

> If the project is required to perform CRUD exclusively through stored
> procedures, use a more restrictive setup: grant `EXECUTE` on the
> specific required procedures instead of granting direct `SELECT`,
> `INSERT`, `UPDATE`, and `DELETE` privileges. The procedure definitions
> and their security configuration must support this arrangement.

## Step 6: Verify the account's privileges

Run:

``` sql
SHOW GRANTS FOR 'PIES_User'@'localhost';
```

Confirm that the output includes the expected privileges on `unidb`.

## Step 7: Test logging in with the new account

Exit the administrator session:

``` sql
EXIT;
```

From the terminal, connect using the new account:

``` bash
mysql -u PIES_User -p -h localhost -P 3306 unidb
```

When prompted, enter:

``` text
pies1234
```

After connecting, run:

``` sql
SELECT DATABASE();
SHOW TABLES;
```

`SELECT DATABASE()` should return `unidb`. `SHOW TABLES` should list the
tables in that schema, if any exist.

You can then exit:

``` sql
EXIT;
```

## Step 8: Configure the PIES Django project

In the project's `settings.py`, configure the `unidb` database
connection:

``` python
DATABASES = {
    'unidb': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'unidb',
        'USER': 'PIES_User',
        'PASSWORD': 'pies1234',
        'HOST': 'localhost',
        'PORT': '3306',
    }
}
```

Install the MySQL driver in the project's virtual environment if it is
not installed:

``` bash
pip install mysqlclient
```

For a shared or production project, keep the password in an environment
variable rather than committing it to source control.

## Completion checklist

-   [ ] Logged in to MySQL as an administrator.
-   [ ] Confirmed that `unidb` exists.
-   [ ] Created `'PIES_User'@'localhost'`.
-   [ ] Granted the required permissions on `unidb`.
-   [ ] Verified the account's grants.
-   [ ] Successfully logged in using `PIES_User`.
-   [ ] Configured the `unidb` connection in Django's `settings.py`.

## Notes

-   `localhost` is appropriate only when Django connects from the same
    machine as MySQL. If Django runs on a different machine, create an
    account restricted to that machine's host or IP address and
    configure the server to accept remote connections.
-   `FLUSH PRIVILEGES` is not required after `CREATE USER`,
    `ALTER USER`, or `GRANT`.
-   The account is for application access. Continue using an
    administrator account for database administration tasks.
