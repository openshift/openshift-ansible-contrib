# Contributing

## Submitting Code To The Playbooks

Following these guidelines will make it easier for people to review
your code and merge it faster.


1. Please add **documentation** to any user-facing changes you make

If you add a new option, or support for a new feature, please describe
how to use that feature in the relevant README.

2. **Do not rebase** when adding changes to an existing pull request

Make the change as an new commit instead and push it to your branch.
That way, Github lets us see just the new changes, which will make the
review process faster.

When you do a rebase, we can't see what changed before the last
revision and have to look at the entire pull request again -- even if
all you added was a small documentation fix!

If you need to bring in changes from the master, you can do `git merge
master` instead or rebasing.

When we merge the pull request, we will squash your commits so don't
worry about the 15 "fix yet another typo" commits polluting the history.


3. Do stylistic changes (code formatting, indentation, etc.) in a
   **separate** pull request, not when you introduce a new feature

If you pepper your fantastic new feature with a lot of unrelated
changes such as changing the YAML indent or splitting long lines into
shorter ones, it will be harder to focus on the feature or fix you're
adding. This again leads to longer review times and frustrated
reviewers.

It is perfectly fine to submit a standalone PR that says "make all
lines under 80 characters long" or "make the yaml list indentation
consistent".

Be careful about your editor settings: some editors will automatically
re-indent or "fix" any files you open. So please make sure those don't
make it to the final pull request.

4. If your changes involves the Openstack provider, ask @tomassedovic
   or @bogdando to run the end to end test.

These require a bit of manual work to run (we're working on it) and
we'll probably run these on our own but feel free to ask us.

5. If you're adding a new dependency, please call it out and add it to
   the documentation

Especially with Ansible, it is very easy to silently add a new
dependency just by using a new module or a bit of syntax. These are
usually documented on Ansible docs.



## Reviewing the Code

Following these guidelines will make the lives of the contributors
easier and get their changes merged faster.

1. Run (or ask someone to run) the extra CI runs if they're relevant

2. See if there's an Ansible module we can use instead of relying on
   shell and grep

Ansible has a ton of modules that can make the playbooks more robust
and easier to follow. Our contributors may be new to Ansible and not
know about these.

http://docs.ansible.com/ansible/latest/list_of_all_modules.html

3. Be explicit about what you did and didn't test

Did you just look at the code? Did you run the playbooks? Did you do a
full end to end verification of the feature?

4. When asking for changes, try to provide concrete examples

This doesn't have to be a full-blown patch, but a link documenting the
feature you want to use or a code sample that should do what you want
makes it easier for the contributor.

5. Set the Github label to the relevant cloud provider (aws, gce, osp,
   etc.)

6. Do not close an issue someone opened before they had a chance to
   reply to your suggestion.

We should try to make sure the issue was resolved to the reporter's
satisfaction. Our suggestion might not solve their problem entirely,
or we might be missing some context.
