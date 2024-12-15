# CONTRIBUTING.md

## Welcome
Thank you for your interest in contributing to KGSM! This project aims to simplify game server management on GNU/Linux systems with a lightweight and extensible design. Contributions are welcome, whether you're fixing a bug, adding a feature, or improving documentation.

## How to Contribute
1. **Fork** the repository and clone it to your local machine.
2. Create a new branch for your changes: `git checkout -b feature-or-fix-name`.
3. Make your changes following the [coding standards](#coding-standards).
4. Commit your changes: `git commit -m "Brief description of your changes"`.
5. Push to your fork: `git push origin feature-or-fix-name`.
6. Open a pull request with a description of your changes.

## Coding Standards
KGSM uses an `.editorconfig` file to maintain consistent coding styles across different editors. Please ensure your editor respects the following settings:
- Indent style: Spaces
- Indent size: 2
- End of line: LF
- Charset: UTF-8
- Trim trailing whitespace: True
- Insert final newline: True

For shell scripts, follow these additional guidelines:
- Bash is the primary shell variant.
- Adhere to constructs supported by `shellcheck` where possible.

## Reporting Issues and Requesting Features
When submitting an issue, please include:
- The KGSM version you’re using.
- Your operating system and versions of Bash and systemd (if applicable).
- Steps to reproduce the issue.

For suggesting new game server support, use the **New Game Server** issue template, ensuring:
- The server has native Linux support.
- Relevant details like Steam App ID or official download links are provided.

## Testing Contributions
While KGSM currently lacks a testing framework, contributors are encouraged to:
- Manually verify their changes with various configurations.
- Ensure new or existing game server blueprints function as expected.

## Community and Communication
If you have questions or need help, feel free to:
- Open a discussion or issue on GitHub.
- Join the project’s community (add a link if applicable).

## License
By contributing to KGSM, you agree that your contributions will be licensed under the GNU General Public License v3.0 (GPL-3).

