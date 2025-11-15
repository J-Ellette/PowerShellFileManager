<!-- omit in toc -->
# Contributing to PowerShell File Manager

First off, thanks for taking the time to contribute! ❤️

All types of contributions are encouraged and valued. See the [Table of Contents](#table-of-contents) for different ways to help and details about how this project handles them. Please make sure to read the relevant section before making your contribution. It will make it a lot easier for us maintainers and smooth out the experience for all involved. The community looks forward to your contributions. 🎉

> And if you like the project, but just don't have time to contribute, that's fine. There are other easy ways to support the project and show your appreciation, which we would also be very happy about:
>
> - Star the project
> - Tweet about it
> - Refer this project in your project's readme
> - Mention the project at local meetups and tell your friends/colleagues

<!-- omit in toc -->
## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [I Have a Question](#i-have-a-question)
- [I Want To Contribute](#i-want-to-contribute)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)
- [Your First Code Contribution](#your-first-code-contribution)
- [Styleguides](#styleguides)
- [Commit Messages](#git-commit-messages)
- [Join The Project Team](#join-the-project-team)

## Code of Conduct

This project and everyone participating in it is governed by the
[PowerShell File Manager Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code. Please report unacceptable behavior
to .

## I Have a Question

> If you want to ask a question, we assume that you have read the available [Documentation](https://github.com/J-Ellette/PowerShellFileManager).

Before you ask a question, it is best to search for existing [Issues](https://github.com/J-Ellette/PowerShellFileManager/issues) that might help you. In case you have found a suitable issue and still need clarification, you can write your question in this issue. It is also advisable to search the internet for answers first.

If you then still feel the need to ask a question and need clarification, we recommend the following:

- Open an [Issue](https://github.com/J-Ellette/PowerShellFileManager/issues/new).
- Provide as much context as you can about what you're running into.
- Provide project and platform versions (nodejs, npm, etc), depending on what seems relevant.

We will then take care of the issue as soon as possible.

<!--
You might want to create a separate issue tag for questions and include it in this description. People should then tag their issues accordingly.

Depending on how large the project is, you may want to outsource the questioning, e.g. to Stack Overflow or Gitter. You may add additional contact and information possibilities:
- IRC
- Slack
- Gitter
- Stack Overflow tag
- Blog
- FAQ
- Roadmap
- E-Mail List
- Forum
-->

## I Want To Contribute

> ### Legal Notice <!-- omit in toc -->
>
> When contributing to this project, you must agree that you have authored 100% of the content, that you have the necessary rights to the content and that the content you contribute may be provided under the project licence.

### Reporting Bugs

<!-- omit in toc -->
#### Before Submitting a Bug Report

A good bug report shouldn't leave others needing to chase you up for more information. Therefore, we ask you to investigate carefully, collect information and describe the issue in detail in your report. Please complete the following steps in advance to help us fix any potential bug as fast as possible.

- Make sure that you are using the latest version.
- Determine if your bug is really a bug and not an error on your side e.g. using incompatible environment components/versions (Make sure that you have read the [documentation](https://github.com/J-Ellette/PowerShellFileManager). If you are looking for support, you might want to check [this section](#i-have-a-question)).
- To see if other users have experienced (and potentially already solved) the same issue you are having, check if there is not already a bug report existing for your bug or error in the [bug tracker](https://github.com/J-Ellette/PowerShellFileManager/issues?q=label%3Abug).
- Also make sure to search the internet (including Stack Overflow) to see if users outside of the GitHub community have discussed the issue.
- Collect information about the bug:
- Stack trace (Traceback)
- OS, Platform and Version (Windows, Linux, macOS, x86, ARM)
- Version of the interpreter, compiler, SDK, runtime environment, package manager, depending on what seems relevant.
- Possibly your input and the output
- Can you reliably reproduce the issue? And can you also reproduce it with older versions?

<!-- omit in toc -->
#### How Do I Submit a Good Bug Report?

We use GitHub issues to track bugs and errors. If you run into an issue with the project:

- Open an [Issue](https://github.com/J-Ellette/PowerShellFileManager/issues/new). (Since we can't be sure at this point whether it is a bug or not, we ask you not to talk about a bug yet and not to label the issue.)
- Explain the behavior you would expect and the actual behavior.
- Please provide as much context as possible and describe the *reproduction steps* that someone else can follow to recreate the issue on their own. This usually includes your code. For good bug reports you should isolate the problem and create a reduced test case.
- Provide the information you collected in the previous section.

Once it's filed:

- The project team will label the issue accordingly.
- A team member will try to reproduce the issue with your provided steps. If there are no reproduction steps or no obvious way to reproduce the issue, the team will ask you for those steps and mark the issue as `needs-repro`. Bugs with the `needs-repro` tag will not be addressed until they are reproduced.
- If the team is able to reproduce the issue, it will be marked `needs-fix`, as well as possibly other tags (such as `critical`), and the issue will be left to be [implemented by someone](#your-first-code-contribution).

<!-- You might want to create an issue template for bugs and errors that can be used as a guide and that defines the structure of the information to be included. If you do so, reference it here in the description. -->

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion for PowerShell File Manager, **including completely new features and minor improvements to existing functionality**. Following these guidelines will help maintainers and the community to understand your suggestion and find related suggestions.

<!-- omit in toc -->
#### Before Submitting an Enhancement

- Make sure that you are using the latest version.
- Read the [documentation](https://github.com/J-Ellette/PowerShellFileManager) carefully and find out if the functionality is already covered, maybe by an individual configuration.
- Perform a [search](https://github.com/J-Ellette/PowerShellFileManager/issues) to see if the enhancement has already been suggested. If it has, add a comment to the existing issue instead of opening a new one.
- Find out whether your idea fits with the scope and aims of the project. It's up to you to make a strong case to convince the project's developers of the merits of this feature. Keep in mind that we want features that will be useful to the majority of our users and not just a small subset. If you're just targeting a minority of users, consider writing an add-on/plugin library.

<!-- omit in toc -->
#### How Do I Submit a Good Enhancement Suggestion?

Enhancement suggestions are tracked as [GitHub issues](https://github.com/J-Ellette/PowerShellFileManager/issues).

- Use a **clear and descriptive title** for the issue to identify the suggestion.
- Provide a **step-by-step description of the suggested enhancement** in as many details as possible.
- **Describe the current behavior** and **explain which behavior you expected to see instead** and why. At this point you can also tell which alternatives do not work for you.
- You may want to **include screenshots or screen recordings** which help you demonstrate the steps or point out the part which the suggestion is related to. You can use [LICEcap](https://www.cockos.com/licecap/) to record GIFs on macOS and Windows, and the built-in [screen recorder in GNOME](https://help.gnome.org/users/gnome-help/stable/screen-shot-record.html.en) or [SimpleScreenRecorder](https://github.com/MaartenBaert/ssr) on Linux. <!-- this should only be included if the project has a GUI -->
- **Explain why this enhancement would be useful** to most PowerShell File Manager users. You may also want to point out the other projects that solved it better and which could serve as inspiration.

<!-- You might want to create an issue template for enhancement suggestions that can be used as a guide and that defines the structure of the information to be included. If you do so, reference it here in the description. -->

### Your First Code Contribution

We welcome contributions from developers of all skill levels! Here's how to get started:

#### Setting Up Your Development Environment

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:

   ```powershell
   git clone https://github.com/your-username/PowerShellFileManager.git
   cd PowerShellFileManager
   ```

3. **Import the module** for testing:

   ```powershell
   Import-Module .\PowerShellFileManager.psd1
   ```

#### Making Your First Contribution

1. **Find a good first issue** - Look for issues labeled `good first issue` or `help wanted`
2. **Create a feature branch**:

   ```powershell
   git checkout -b feature/your-feature-name
   ```

3. **Follow the coding guidelines** in [.github/copilot-instructions.md](.github/copilot-instructions.md)
4. **Write tests** for your changes when applicable
5. **Test your changes** thoroughly on different platforms if possible
6. **Update documentation** as needed

#### Code Structure

The project follows a modular structure under `src/Modules/`. Place your code in the appropriate module:

- `Core/` - Core functionality (CommandPalette, QueryBuilder, etc.)
- `FileOperations/` - File operations (Batch, Archive, etc.)
- `Navigation/` - Navigation features
- `Search/` - Search functionality
- `Integration/` - External integrations
- `Preview/` - Preview and metadata
- `Security/` - Security operations
- `PowerToys/` - PowerToys integration features
- `System/` - System features (Background ops, Plugins)

### Improving The Documentation

Documentation improvements are always welcome! You can help by:

- Fixing typos or grammatical errors
- Adding examples to function documentation
- Improving existing documentation for clarity
- Writing new documentation for undocumented features
- Translating documentation to other languages

#### Documentation Guidelines

- Use comment-based help for PowerShell functions
- Follow markdown best practices
- Include practical examples
- Keep language clear and concise
- Update the README.md when adding new features

## Styleguides

### PowerShell Code Style

Follow the guidelines in [.github/copilot-instructions.md](.github/copilot-instructions.md):

1. **Naming Conventions**
   - Use approved PowerShell verbs (Get-, Set-, New-, Remove-, etc.)
   - Follow PascalCase for function names
   - Use PascalCase for parameters with descriptive names

2. **Function Structure**
   - Include parameter validation using `[Parameter()]` attributes
   - Support `-WhatIf` and `-Confirm` for destructive operations
   - Include comprehensive comment-based help
   - Use proper error handling with try/catch blocks

3. **Code Organization**
   - Keep functions focused and single-purpose
   - Export only public functions
   - Follow the existing module structure

### Git Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line
- Consider starting the commit message with an applicable emoji:
  - 🎨 `:art:` when improving the format/structure of the code
  - 🐎 `:racehorse:` when improving performance
  - 📝 `:memo:` when writing docs
  - 🐛 `:bug:` when fixing a bug
  - 🔥 `:fire:` when removing code or files
  - ✅ `:white_check_mark:` when adding tests

## Join The Project Team

Interested in becoming a maintainer? We're always looking for dedicated contributors who:

- Have made several quality contributions to the project
- Understand the project's goals and architecture
- Are committed to helping other contributors
- Can dedicate time to regular maintenance tasks

If you're interested, please reach out by opening an issue expressing your interest and highlighting your contributions to the project.
