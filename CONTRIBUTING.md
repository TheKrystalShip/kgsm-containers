# Contributing to KGSM-Containers

Thank you for your interest in contributing to the KGSM-Containers project! Your contributions help expand the range of game servers that can be easily managed through KGSM.

## Table of Contents
- [Contributing to KGSM-Containers](#contributing-to-kgsm-containers)
  - [Table of Contents](#table-of-contents)
  - [Ways to Contribute](#-ways-to-contribute)
  - [Image Structure Standards](#-image-structure-standards)
    - [Technical Requirements](#technical-requirements)
    - [Attribution and Credit](#attribution-and-credit)
  - [Quick Start Guide](#-quick-start-guide)
    - [Setting Up](#setting-up)
  - [Working with Templates](#-working-with-templates)
    - [Dockerfile Template](#dockerfile-template)
    - [Management Script (.manage.sh)](#management-script-managesh)
    - [Build Script (build.sh)](#build-script-buildsh)
  - [Testing Your Image](#-testing-your-image)
  - [� Submission Process](#-submission-process)
  - [Pull Request Checklist](#-pull-request-checklist)
  - [Keeping Your Fork Updated](#-keeping-your-fork-updated)
  - [Getting Help](#-getting-help)

## Ways to Contribute

- **New Game Server Images**: Add support for game servers not yet included
- **Image Improvements**: Enhance existing images for better performance, security, or functionality
- **Documentation**: Improve or add documentation for container usage
- **Bug Fixes**: Fix issues with existing container images

## Image Structure Standards

### Technical Requirements

1. **Base Image**: Use `steamcmd/steamcmd:debian` for consistency
2. **Non-root User**: Run as the `kgsm` user with minimal necessary permissions
3. **Directory Structure**: Standard paths under `/opt/<game-name>/` (backups, install, logs, saves, temp)
4. **Templates**: Use the provided templates in the `templates/` directory
5. **Management Script**: Server should start automatically when container launches

### Attribution and Credit

Every contributor will receive proper credit for their work:

- Your name and contact information will be included in file headers
- Original sources will be credited when work is adapted from other projects
- Attribution headers remain with files permanently

## Quick Start Guide

### Setting Up

1. Fork this repository and create a new branch
2. Set up your game directory and copy templates:
   ```bash
   # Create game directory
   mkdir -p images/<game-name>
   
   # Copy and rename templates
   cp templates/Dockerfile templates/build.sh templates/container.manage.sh images/<game-name>/
   mv images/<game-name>/container.manage.sh images/<game-name>/<game-name>.manage.sh
   ```

## Working with Templates

All new game server images should use the provided template files. Each template has clearly marked sections for customization.

### Dockerfile Template

Modify only these key sections:
- Header comments with game name and attribution
- Exposed ports specific to your game server
- Dependencies required by your game
- Environment variables specific to your game

### Management Script (<game-name>.manage.sh)

- Based on `templates/container.manage.sh`
- Modify only the configuration variables section at the top
- Handles server initialization, startup, and lifecycle
- Examine existing management scripts for examples

### Build Script (build.sh)

- Minimal modifications needed - primarily the game name
- Used for local testing and by the main build system

## Testing Your Image

1. Build your container:
   ```bash
   cd kgsm-containers/images/<game-name>
   ./build.sh
   ```

2. Run and test your container:
   ```bash
   docker run -it \
     --name <game-name> \
     -p <port>:<port>/udp \
     -v <game-name>-data:/opt/<game-name> \
     <game-name>:latest
   ```

3. Verify the server starts automatically and functions correctly

## � Submission Process

1. Ensure your image passes all tests
2. Commit with descriptive messages
3. Push to your fork
4. Open a pull request with details about the new game server

The maintainers will:
1. Review your code
2. Potentially request changes
3. Build and publish the official image after approval

## Pull Request Checklist

- [ ] Based on templates (`Dockerfile`, `build.sh`, `container.manage.sh`)
- [ ] Proper attribution headers included
- [ ] Original sources credited where applicable
- [ ] Management script starts server automatically
- [ ] Game ports correctly exposed
- [ ] Only necessary template sections modified
- [ ] Image thoroughly tested
- [ ] No registry pushing code included
- [ ] Documentation updated

## Keeping Your Fork Updated

```bash
# Add upstream and fetch changes
git remote add upstream https://github.com/TheKrystalShip/KGSM-Containers.git
git fetch upstream
git merge upstream/main
```

## Getting Help

If you have questions or need assistance:
- Check existing game server implementations for examples
- Open an issue in the repository
- Contact the maintainers directly

Thank you for contributing to KGSM-Containers!
