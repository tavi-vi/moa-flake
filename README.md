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

# Caveat Emptor

You might not want to use this. I'm ignoring the versions of the libraries that moa
requests in its requirements.txt. I just jiggled around the versions until it worked.
It does seem to work alright though.

I had to patch a few things to make it work with Postgres, but these changes should
be compatible with MySQL too. Check [Merge request 9](https://gitlab.com/fedstoa/moa/-/merge_requests/9)
to see if it's been upstreamed.

I'm also doing moderate shenanigans to get it to run in /var/lib/moa. I don't think
that would make it behave strange, but you never know.

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
[example in this repository](moa_example.conf). You'll need application keys for
the config. How to get them isn't covered here because it will almost certainly
change. But you will need access to the extended API v1.1 endpoints for some
reason. Twitter is calling this "Elevated" access now. You can request access and
get it without having to wait for a review, you just have to fill out the form.

Then you'll need (? this may be optional, not sure.) to run moa-models from this
flake. It sets up the database the rest of the way.

Now, if you're on Nixos, add the "moa" nixosModule in this flake to your
configuration. Then set `services.moa.enable`, `services.moa.listenAddress`,
and `services.moa.frequency`. Reference the flake definition for documentation.

If I'm remembering all of what I did correctly, that should be all that's required
to run Moa! Feel free to file an issue if this doesn't work for you, but be warned,
I might be too busy to investigate what went wrong.

# Previous art

https://vitobotta.com/2022/11/12/setting-up-a-mastodon-twitter-crossposter/ (please
don't follow these instructions. It tells you to just run app.py, which uses the flask
development server, which is 
[not meant for any use other than development](https://flask.palletsprojects.com/en/2.2.x/deploying/).)
