# Moa Flake

This is a nixos flake that provides the packages for Moa, moa-worker, and moa-models.
These run the webserver, the crossposter and the database initialization respectively.

I can't guarantee that this works correctly, or is safe. I'm running this on the
internet, but behind my own [login page](https://github.com/tavi-vi/convAuth).
If you're comfortable with the risk or want to run it in a safe environment, see
the instructions below.

If nothing else, I hope this can provide a documentation of how to run Moa. There
are some nix-specific things in there, keep that in mind.

These scripts modify how Moa works to be more like how Unix services usually work.
It uses the directory /var/lib/moa for logs and lock files, and the configuration
is expected to be at /etc/moa.config. The configuration format is unchanged, it's
still just python, like `config.py.sample` in the Moa source. It expects you to
define a ProductionConfig class.

# Setup

The setup process should be simple, but I'm not gonna follow my own steps to verify,
sorry.

You need Postgresql setup and running. You'll have to create a user (I used `moa`)
in Postgres and save the password to put in the config. I created the database
"moa" in Postgres manually, and ran the following postgres commands (queries?) in
a psql commandline:

```
GRANT CONNECT ON DATABASE moa TO moa;
GRANT ALL PRIVILEGES ON DATABASE moa TO moa;
```

You'll want to setup your config at this point. There's an
(example in this repository)[moa_example.config].

Then you'll need (? this may be optional, not sure.) to run moa-models from this
flake. It sets up the database the rest of the way.

Now, if you're on Nixos, add the "moa" nixosModule in this flake to your
configuration. Then set `services.moa.enable`, `services.moa.listenAddress`,
and `services.moa.frequency`. Reference the flake definition for documentation.

If I'm remembering all of what I did correctly, that should be all that's required
to run Moa! Feel free to file an issue if this doesn't work for you, but be warned,
I might be too busy to investigate what went wrong.
