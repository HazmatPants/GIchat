# How to contribute

Fork the repo, click Fork (top-right).

Clone your fork locally:
```sh
git clone https://github.com/<your-username>/GIchat.git
```

Add this repo as an upstream:
```sh
git remote add upstream https://github.com/HazmatPants/GIchat.git
```
This lets you pull future updates from the original repo with:
```sh
git fetch upstream
```

Create a new branch for your changes, example:
```sh
git checkout -b my-server-fix upstream/server
```
Or for the client:
```
git checkout -b my-client-fix upstream/client
```

Now make your changes.

Commit your changes:
```sh
git add .
git commit -m "Fix issue in script"
```

Push to your fork:
```sh
git push origin fix-typo-in-readme
```

Open a pull request, go to your fork and click "Compare & pull request". Explain what you changed and why.
