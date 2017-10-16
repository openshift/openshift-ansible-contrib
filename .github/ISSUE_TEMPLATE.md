<!-- Thanks for filing an issue! Before hitting the button, please answer these questions.-->

Is this a **BUG REPORT** or a **FEATURE REQUEST** ? (choose one):

<!--
If this is a BUG REPORT, please:
  - Fill in as much of the template below as you can.  If you leave out
    information, we can't help you as well.

If this is a FEATURE REQUEST, please:
  - Describe *in detail* the feature/behavior/change you'd like to see. Note,
    for simple and tiny features or change requests we encourage you opening
    a pull request with a proposed implementation.

In both cases, be ready for followup questions, and please respond in a timely
manner.  If we can't reproduce a bug or think a feature already exists, we
might close your issue.  If we're wrong, PLEASE feel free to reopen it and
explain why.
-->

# BUG REPORT INFO

### Environment

- **Cloud provider**:  

- **OS details** (`printf "$(uname -srm)\n$(cat /etc/os-release)\n"`):  

- **Version of Ansible** (`ansible --version`):  

- **Version of Jinja** (`pip freeze | grep -i jinja`):  

- **Version of Shade** (`pip freeze | grep -i shade`):  

- **The openstack-ansible-contrib version (commit)** (`git rev-parse --short HEAD`):  


**Copy of inventory files and custom variables used (please omit your secrets!)**:  


**Command used to invoke ansible**:  


**Output of ansible run**:  
<!-- We recommend using snippets services like https://gist.github.com/ etc. -->

**Anything else do we need to know**:  


# FEATURE REQUEST INFO

An introduction paragraph with "[tl;dr]" info.

## Problem Description

What problem is being solved by the proposed feature?

What are the use cases for End User vs Deployer?

Also describe the target cloud provider.

## Proposed Change

Describe the change you would like to make.

### Overview

### Alternatives

### Security Impact

### Other End User Impact

### Performance Impact

### Other Deployer Impact

### Developer Impact

### Documentation Impact

## Implementation

Describe your plan for implementation steps and potential
assignees/contributors.

## Acceptance criteria

Provide a definition of done and acceptance criteria.

## Testing

Describe how to test this, including manual steps, if any.

## Dependencies

## References
