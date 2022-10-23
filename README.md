# You Need An Importer

Quick and dirty project to import bank transactions into
[YNAB](https://www.youneedabudget.com/).

Supports importing transactions from [banks supported by Nordigen](https://nordigen.com/en/coverage/).

Requirements:
- [Ruby](https://www.ruby-lang.org/)
- [Bundler](https://bundler.io/)
- A (free) [Nordigen](https://nordigen.com/) account
- A [YNAB](https://www.youneedabudget.com/) account (obviously)

# Bootstrap

Run bundle to install dependencies:

``` shell
$ bundle
```

# Usage

## Fetch
The `fetch` command fetches transactions from the bank and stores them
in an SQLite database.

### Setup

Register with Nordigen and create a [user
secret](https://ob.nordigen.com/user-secrets/). Now run the `register`
sub-command:

``` shell
$ ./fetch register
```

It'll ask for the secret ID and key, the country code of your bank and
list all the supported banks. Enter the ID of your bank and it will
give you an URL to open in your browser that will authenticate the
fetch command.

After completing the authentication (when it redirects you to
`https://google.com`), it'll fetch a list of all accounts and store in
the database.

Configuration is saved at each step into `.fetch.yml`, so it's safe to
kill the command and re-run it. If you make a mistake, remove the
`.fetch.yml` and start over, or, if you're comfortable editing YAML
files, edit it.

### Running

When the setup is complete, you can run the transaction fetching:

``` shell
$ ./fetch run
```

This will fetch transactions from your bank and store them in the
SQLite database.

## Push

The `push` command takes transactions from the SQLite database and
imports them into YNAB.

### Setup

First, create a personal access token at [your settings page on
YNAB](https://app.youneedabudget.com/settings/developer) and make a
note of it (it will only be visible when created).

Simply running the command will configure it on the first run.

``` shell
$ ./push
```

It'll ask for the personal access token you created, ask for each bank
account which YNAB budget and account to import it into, and do the
first import.

Like `fetch` it will save its configuration into `.push.yml` at each
step.

# General usage

After setup, it's just running both commands to do the import:

``` shell
./fetch run && ./push
```

You can get help on options for both commands by supplying the
`-h`/`--help` switch.

# Bugs

- Transactions with the same description, amount and date is likely to
  be lost, but this is likely a YNAB bug.
- Doesn't handle changes in transactions, but transactions shouldn't
  change anyway.
  
