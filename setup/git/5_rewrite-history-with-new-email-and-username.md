Install python `git-filter-repo` package

```
$ pip install git-filter-repo
```

Run command as below (replace old-email and new-email)

```
$ git filter-repo --commit-callback '
>> if commit.author_email == b"robbi.nespu@old-email.com":
>>     commit.author_email = b"robbi.nespu@new-email.com"
>>     commit.author_name  = b"Robbi Nespu"
>> if commit.committer_email == b"robbi.nespu@old-email.com":
>>     commit.committer_email = b"robbi.nespu@new-email.com"
>>     commit.committer_name  = b"Robbi Nespu"
>> '
```

You will get output as below

```
NOTICE: Removing 'origin' remote; see 'Why is my origin removed?'
        in the manual if you want to push back there.
        (was git@gitlab.com:xyz/sys-middlware.git)
Parsed 240 commits
New history written in 1.61 seconds; now repacking/cleaning...
Repacking your repo and cleaning out old unneeded objects
HEAD is now at b25eade Delete README.md
Enumerating objects: 4145, done.
Counting objects: 100% (4145/4145), done.
Delta compression using up to 24 threads
Compressing objects: 100% (1451/1451), done.
Writing objects: 100% (4145/4145), done.
```

As you notice, your `origin remote` are removed. It for safety measure. 
If you confident, add it back

```
$ git remote add origin git@gitlab.com:xyz/sys-middlware.git
```

Finally, git push force
```
git push --force --all
git push --force --tags
```

🚨 Everyone else must re-clone or reset
