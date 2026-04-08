# GitHub Copilot Instructions for Knife Repository

## Repository Overview

The **knife** repository is a command-line tool that provides an interface between a local Chef repository and the Chef Infra Server. This is a standalone engineering excellence repository extracted from the chef/chef monorepo for testing builds, pipelines, and development workflows as a separate gem.

### Project Purpose
Knife is the command-line interface for Chef Infra, allowing developers and system administrators to interact with Chef servers, manage nodes, upload cookbooks, and perform various Chef-related operations from the command line.

### Technology Stack
- **Primary Language**: Ruby (3.1+ required)
- **Testing Framework**: RSpec
- **Build System**: Rake + Bundler + Habitat
- **Packaging**: RubyGems + Habitat packages
- **CI/CD**: Expeditor (Chef's automation platform)
- **Quality Assurance**: SonarQube integration

## Repository Structure

```
/Users/asaidala/Projects/knife/
├── .expeditor/                    # Expeditor CI/CD configuration
│   ├── config.yml                 # Main Expeditor config with pipelines
│   ├── verify.pipeline.yml        # PR validation pipeline
│   ├── habitat-test.pipeline.yml  # Habitat artifact testing
│   └── build.habitat.yml          # Habitat build configuration
├── .github/                       # GitHub configuration
│   ├── workflows/                 # GitHub Actions workflows
│   │   └── sonarqube.yml         # SonarQube code quality analysis
│   └── copilot-instructions.md   # This file
├── bin/                          # Executable binaries
│   └── knife                     # Main knife executable
├── chef-server/                  # Development Chef server setup
│   ├── Dockerfile                # Docker configuration for Chef server
│   ├── Vagrantfile              # Vagrant setup for local testing
│   └── chef-keys/               # Development authentication keys
├── docs/                         # Documentation
│   └── dev/README.md            # Developer setup guide
├── habitat/                      # Habitat packaging configuration
│   ├── plan.sh                  # Linux/macOS Habitat plan
│   ├── plan.ps1                 # Windows Habitat plan
│   └── tests/                   # Habitat package tests
├── lib/                          # Core library code
│   └── chef/                     # Chef namespace
│       ├── application/         # Application entry points
│       ├── chef_fs/             # Chef file system abstraction
│       ├── knife/               # Main knife commands and utilities
│       │   ├── core/            # Core knife functionality
│       │   ├── bootstrap/       # Node bootstrap functionality
│       │   └── *.rb             # Individual knife subcommands
│       └── knife.rb             # Main knife class
├── spec/                         # RSpec test suite
│   ├── unit/                    # Unit tests
│   ├── functional/              # Functional tests
│   ├── integration/             # Integration tests
│   ├── support/                 # Test support files
│   └── data/                    # Test fixtures and data
├── file_cook/                    # Example cookbook for testing
├── frozen_file_cook/            # Frozen cookbook example
├── Gemfile                      # Ruby dependencies
├── knife.gemspec               # Gem specification
├── Rakefile                    # Build tasks
├── CHANGELOG.md                # Version history
└── VERSION                     # Current version (19.0.73)
```

## Development Workflow Integration

### Phase-Based Development Process

All development work must follow a structured, prompt-based approach with explicit approval gates between phases.

#### Phase 1: Initial Setup & Analysis
**Objective**: Understand requirements and plan implementation

**When Jira ID is provided:**
1. **Jira Analysis**: 
   ```
   I'll fetch the Jira issue details for [JIRA_ID] to understand the requirements.
   ```
   - Use atlassian-mcp-server to fetch issue details
   - Read and summarize the story/task requirements
   - Identify acceptance criteria
   - Note any dependencies or constraints

2. **Repository Analysis**:
   - Analyze current codebase relevant to the task
   - Identify affected files and components
   - Review existing tests and patterns
   - Check for related functionality

3. **Implementation Planning**:
   - Create detailed implementation plan
   - Identify new files needed
   - Plan test strategy with >80% coverage requirement
   - Estimate scope and complexity

**Approval Gate**: "Phase 1 complete. I've analyzed the requirements and created an implementation plan. Do you want me to continue with Phase 2 (Implementation)?"

#### Phase 2: Implementation Phase
**Objective**: Implement the functionality with comprehensive testing

**Steps**:
1. **Code Implementation**:
   - Implement core functionality following Ruby/Chef patterns
   - Follow existing code style and conventions
   - Add proper error handling and edge cases
   - Include comprehensive documentation

2. **Unit Test Creation** (CRITICAL REQUIREMENT):
   - Create comprehensive unit tests for all new functionality
   - Achieve >80% test coverage (non-negotiable hard requirement)
   - Test positive scenarios, negative scenarios, and edge cases
   - Use mocks for external dependencies
   - Follow RSpec patterns established in the codebase

3. **Integration Test Updates**:
   - Add/update functional and integration tests as needed
   - Ensure tests are independent and can run in any order

**Test Coverage Requirements (CRITICAL)**:
- **>80% code coverage is mandatory and non-negotiable**
- Test both success and failure paths
- Test edge cases and boundary conditions
- Mock external dependencies appropriately
- Ensure all public methods have test coverage
- Test error handling and exception paths

**Approval Gate**: "Phase 2 complete. Implementation and comprehensive testing finished with >80% coverage. Do you want me to continue with Phase 3 (Testing Validation)?"

#### Phase 3: Testing Phase
**Objective**: Validate implementation through test execution

**Steps**:
1. **Test Execution**:
   ```bash
   bundle exec rake spec
   ```

2. **Coverage Verification**:
   - Verify >80% test coverage requirement is met
   - Check that all new functionality is properly tested
   - Ensure no regressions in existing functionality

3. **Quality Checks**:
   - Run any available linting tools
   - Check for code style compliance
   - Verify all tests pass

**Approval Gate**: "Phase 3 complete. All tests pass with >80% coverage verified. Do you want me to continue with Phase 4 (Pull Request Creation)?"

#### Phase 4: Pull Request Creation
**Objective**: Create PR with proper documentation and compliance

**Git Operations** (All using GH CLI, no profile-based auth):
1. **Branch Creation**:
   ```bash
   git checkout -b [JIRA_ID]
   ```

2. **DCO Compliant Commit**:
   ```bash
   git add .
   git commit --signoff -m "[JIRA_ID]: [description]"
   ```

3. **Push to Remote**:
   ```bash
   git push origin [JIRA_ID]
   ```

4. **PR Creation**:
   ```bash
   gh pr create --title "[JIRA_ID]: [title]" --body "[HTML_FORMATTED_DESCRIPTION]" --label "[appropriate_labels]"
   ```

**Final Approval Gate**: "Phase 4 complete. Pull request created with proper DCO compliance and documentation. Development workflow finished."

## Critical Testing Requirements

### Hard Requirements (Non-Negotiable)
- **>80% test coverage for all implementations** - This is CRITICAL and MANDATORY
- **>80% test coverage for all implementations** - Emphasized again for importance
- **>80% test coverage for all implementations** - Cannot be compromised
- All commits MUST use DCO signoff (`--signoff` flag)
- All tests must pass before PR creation
- Both positive and negative scenarios must be tested

### RSpec Testing Patterns

**Unit Test Structure**:
```ruby
# spec/unit/knife/[command_name]_spec.rb
require "knife_spec_helper"

describe Chef::Knife::[CommandName] do
  let(:knife) { described_class.new }
  let(:ui) { double("UI") }
  
  before do
    allow(knife).to receive(:ui).and_return(ui)
  end

  describe "#run" do
    context "when valid arguments provided" do
      it "performs the expected operation" do
        # Test implementation
      end
    end

    context "when invalid arguments provided" do
      it "displays error message" do
        # Test error handling
      end
    end

    context "edge cases" do
      it "handles edge case appropriately" do
        # Test boundary conditions
      end
    end
  end
end
```

**Mock External Dependencies**:
```ruby
let(:chef_server_rest) { double("Chef::ServerAPI") }

before do
  allow(Chef::ServerAPI).to receive(:new).and_return(chef_server_rest)
  allow(chef_server_rest).to receive(:get).and_return(mock_data)
end
```

### Test Execution Commands
```bash
# Run all tests
bundle exec rake spec

# Run specific test file
bundle exec rspec spec/unit/knife/specific_command_spec.rb

# Run tests with coverage (if available)
bundle exec rake spec

# Run tests with verbose output
bundle exec rspec spec/unit/knife/specific_command_spec.rb --format documentation
```

## DCO (Developer Certificate of Origin) Compliance

### Critical DCO Requirements
- **ALL commits MUST include DCO signoff**
- **Builds will FAIL without proper DCO signoff**
- **Use `git commit --signoff` or `git commit -s` for all commits**

### DCO Commands
```bash
# Standard commit with DCO signoff
git commit --signoff -m "[JIRA_ID]: description"

# Short form
git commit -s -m "[JIRA_ID]: description"

# Amend existing commit to add signoff
git commit --amend --signoff --no-edit

# Add signoff to last commit if forgotten
git commit --amend --signoff
```

### What DCO Signoff Means
By adding the `--signoff` flag, you're adding a "Signed-off-by" line that certifies:
- You wrote the code or have the right to submit it
- You agree to the Developer Certificate of Origin
- The contribution is made under the project's license (Apache 2.0)

## Build System Integration

### Expeditor Configuration
The repository uses Expeditor for automated builds and releases:

**Available Skip Labels**:
- `Expeditor: Skip All` - Skip all Expeditor actions
- `Expeditor: Skip Version Bump` - Skip automatic version bumping
- `Expeditor: Skip Changelog` - Skip changelog updates
- `Expeditor: Skip Habitat` - Skip Habitat package building

**When to Use Skip Labels**:
- **Documentation-only changes**: Use `Expeditor: Skip All`
- **Test-only changes**: Use `Expeditor: Skip Version Bump`
- **CI/tooling changes**: Use `Expeditor: Skip Version Bump`
- **Bug fixes requiring release**: No skip labels
- **New features**: No skip labels

**Build Channels**:
- `base-2025-current` - Latest unstable builds
- `base-2025` - Stable release channel  
- `stable` - Production-ready releases

### Available Build Commands
```bash
# Install dependencies
bundle install

# Run tests
bundle exec rake spec
bundle exec rspec

# Build gem locally
rake build

# Install gem locally  
rake install

# Build Habitat package (requires Habitat CLI)
hab pkg build .

# Run specific test suites
bundle exec rspec spec/unit/
bundle exec rspec spec/functional/
bundle exec rspec spec/integration/
```

### Rake Tasks
```bash
# List available tasks
rake -T

# Primary tasks:
rake spec          # Run all RSpec tests  
rake build         # Build knife-[version].gem into pkg/ directory
rake install       # Build and install gem locally
rake release       # Create tag v[version], build, and push gem to rubygems.org
```

## GitHub Label Management

### Repository-Specific Labels
```
bug                 - Something isn't working
documentation       - Improvements or additions to documentation  
duplicate          - This issue or pull request already exists
enhancement        - New feature or request
good first issue   - Good for newcomers
help wanted        - Extra attention is needed
invalid            - This doesn't seem right
question           - Further information is requested
wontfix            - This will not be worked on
```

### Label Selection Guidelines
- **Bug fixes**: Use `bug` label
- **New features**: Use `enhancement` label  
- **Documentation updates**: Use `documentation` label + skip labels
- **Test-only changes**: Use appropriate skip labels
- **CI/build changes**: Use skip version bump labels
- **Good for new contributors**: Add `good first issue`

## Pull Request Creation Process

### Branch Naming Convention
Use Jira ID as branch name: `PROJ-123`

### Git Workflow Commands
```bash
# 1. Create and checkout feature branch
git checkout -b [JIRA_ID]

# 2. Make changes and stage them
git add .

# 3. Commit with DCO signoff (REQUIRED)
git commit --signoff -m "[JIRA_ID]: Brief description of changes"

# 4. Push to remote repository
git push origin [JIRA_ID]

# 5. Create pull request with GH CLI
gh pr create \
  --title "[JIRA_ID]: Title from Jira ticket" \
  --body "$(cat pr_description.html)" \
  --label "enhancement,documentation"
```

### PR Description Template (HTML Format)
```html
<h2>Summary</h2>
<p>Brief description of changes made in this PR.</p>

<h2>Related Jira Ticket</h2>
<p><a href="https://jira.company.com/browse/[JIRA_ID]">[JIRA_ID]</a></p>

<h2>Changes Made</h2>
<ul>
  <li>Implemented [specific functionality]</li>
  <li>Added comprehensive unit tests (>80% coverage)</li>
  <li>Updated documentation as needed</li>
  <li>Added error handling for edge cases</li>
</ul>

<h2>Testing Performed</h2>
<ul>
  <li>Unit tests: All passing with >80% coverage</li>
  <li>Integration tests: [status]</li>
  <li>Manual testing: [scenarios tested]</li>
</ul>

<h2>Files Modified</h2>
<ul>
  <li><code>lib/chef/knife/[new_command].rb</code> - New knife command implementation</li>
  <li><code>spec/unit/knife/[new_command]_spec.rb</code> - Comprehensive unit tests</li>
  <li><code>docs/[relevant_doc].md</code> - Documentation updates</li>
</ul>

<h2>Coverage Results</h2>
<pre>
Coverage: 85.2% (Above required 80% threshold)
Total Lines: 1,234
Covered Lines: 1,052
</pre>
```

## Code Quality & Development Standards

### Ruby Code Style
- Follow existing code patterns in the repository
- Use descriptive method and variable names
- Include comprehensive documentation for public APIs
- Handle errors gracefully with appropriate exceptions
- Use consistent indentation (2 spaces)

### Error Handling Patterns
```ruby
# Standard knife error handling
def run
  validate_arguments!
  perform_operation
rescue ArgumentError => e
  ui.fatal(e.message)
  show_usage
  exit(1)
rescue Net::HTTPServerException => e
  ui.fatal("Server error: #{e.message}")
  exit(1)
end

private

def validate_arguments!
  if name_args.empty?
    ui.fatal("You must specify a name argument")
    show_usage
    exit(1)
  end
end
```

### Knife Command Structure
```ruby
class Chef
  class Knife
    class CommandName < Knife
      
      banner "knife command-name [ARGS] (options)"

      deps do
        require "chef/[required_dependencies]"
      end

      option :flag_name,
        short: "-f",
        long: "--flag-name",
        description: "Description of flag"

      def run
        validate_arguments!
        perform_main_operation
      end

      private

      def validate_arguments!
        # Validation logic
      end

      def perform_main_operation
        # Main functionality
      end
    end
  end
end
```

### Security and Compliance
- All code must comply with Apache 2.0 license
- Include appropriate license headers in new files
- Handle sensitive data (passwords, keys) securely
- Validate all user inputs to prevent injection attacks
- Use secure communication protocols for server interactions

### License Header Template
```ruby
#
# Copyright:: Copyright (c) 2009-2026 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
```

## File Modification Guidelines

### Safe to Modify
- `lib/chef/knife/*.rb` - Individual knife commands
- `lib/chef/knife/core/*.rb` - Core utilities and helpers
- `spec/**/*_spec.rb` - All test files
- `docs/**/*.md` - Documentation files
- Individual command files for new functionality

### Modify with Caution
- `lib/chef/knife.rb` - Main knife class (coordinate changes)
- `lib/chef/application/knife.rb` - Application entry point
- `knife.gemspec` - Gem specification (for dependency changes)
- `Rakefile` - Build configuration

### Prohibited/Generated Files (DO NOT MODIFY)
- `VERSION` - Managed by Expeditor automation
- `.expeditor/config.yml` - CI/CD configuration (coordinate changes)
- `CHANGELOG.md` - Generated by Expeditor
- `Gemfile.lock` - Generated by Bundler
- `vendor/` - Third-party dependencies

## Integration & Dependencies

### Chef Ecosystem Integration
Knife integrates with multiple Chef components:
- **Chef Infra Server**: Primary API communication
- **Chef Workstation**: Part of the development toolkit
- **Chef Habitat**: Packaging and deployment
- **Cookbooks**: Upload, download, and management
- **Nodes**: Bootstrap, configuration, management
- **Policies**: Policy-based configuration management

### External Dependencies
Key external dependencies (defined in `knife.gemspec`):
- `train-core` - Transport abstraction for remote connections
- `train-winrm` - Windows remote management
- `tty-prompt` - Interactive command-line prompts  
- `tty-screen` - Terminal screen information
- `tty-table` - Table formatting for output
- `highline` - Advanced command-line interactions
- `pastel` - Terminal color output
- `erubis` - ERB template processing

### Development Dependencies
- `rspec` - Testing framework
- `cookstyle` - Ruby code style enforcement (Chef's RuboCop configuration)
- `bundler` - Dependency management

## Troubleshooting Common Issues

### Test Failures
```bash
# Run single test file to isolate issues
bundle exec rspec spec/unit/knife/specific_command_spec.rb -v

# Run with backtrace for debugging
bundle exec rspec spec/unit/knife/specific_command_spec.rb --backtrace

# Check for missing dependencies
bundle install
```

### Build Issues
```bash
# Clear bundler cache
bundle clean --force

# Reinstall dependencies
rm Gemfile.lock
bundle install

# Check Ruby version compatibility
ruby --version  # Should be 3.1+
```

### DCO Signoff Issues
```bash
# Add signoff to existing commits
git rebase --signoff HEAD~[number_of_commits]

# Or amend last commit
git commit --amend --signoff --no-edit
```

### Coverage Issues
- Ensure all public methods have corresponding tests
- Test both success and failure code paths
- Add tests for edge cases and boundary conditions
- Mock external dependencies to focus on unit being tested

## Prompt-Based Execution Protocol

### Interaction Pattern
All development tasks must follow this conversational pattern:

1. **Task Acknowledgment**: Confirm understanding of the request
2. **Phase Execution**: Execute current phase completely  
3. **Progress Summary**: Summarize what was accomplished
4. **Next Step Preview**: Clearly state what the next phase involves
5. **Approval Request**: "Do you want me to continue with [next phase]?"
6. **Wait for Confirmation**: Do not proceed until user approves
7. **Remaining Work**: List remaining phases to be completed

### Example Interaction Flow
```
User: Please implement feature XYZ for Jira ticket PROJ-123

Copilot: I'll implement feature XYZ following our phase-based development process.

Phase 1: Initial Setup & Analysis
- Fetching Jira ticket PROJ-123 details...
- [Analysis results]
- Created implementation plan with test strategy for >80% coverage

Phase 1 complete. I've analyzed the requirements and created a comprehensive implementation plan. 

Next step: Phase 2 will involve implementing the core functionality and creating comprehensive unit tests to meet the >80% coverage requirement.

Remaining phases: Implementation (Phase 2), Testing Validation (Phase 3), PR Creation (Phase 4)

Do you want me to continue with Phase 2 (Implementation)?

User: Yes, continue

Copilot: Phase 2: Implementation
- Implemented core functionality in lib/chef/knife/xyz.rb
- Created comprehensive unit tests with >85% coverage
- Added integration tests and error handling
- [Detailed summary of changes]

Phase 2 complete. Implementation finished with >80% test coverage achieved.

Next step: Phase 3 will validate the implementation by running the full test suite and verifying coverage requirements.

Remaining phases: Testing Validation (Phase 3), PR Creation (Phase 4)

Do you want me to continue with Phase 3 (Testing Validation)?
```

## Advanced Development Patterns

### Custom Knife Plugin Structure
```ruby
# lib/chef/knife/custom_command.rb
class Chef
  class Knife
    class CustomCommand < Knife
      # Plugin metadata
      category "custom"
      banner "knife custom command [ARGS] (options)"

      # Dependencies loaded on demand
      deps do
        require "chef/node"
        require "chef/api_client_v1"
      end

      # Command options
      option :recursive,
        short: "-r",
        long: "--recursive",
        boolean: true,
        default: false,
        description: "Perform operation recursively"

      # Main execution
      def run
        validate_and_parse_options
        ui.info("Executing custom command...")
        # Implementation
      end

      private

      def validate_and_parse_options
        if name_args.length < 1
          show_usage
          ui.fatal("You must specify at least one argument")
          exit(1)
        end
      end
    end
  end
end
```

### Test Helper Patterns
```ruby
# spec/support/knife_helpers.rb
module KnifeHelpers
  def knife_command(command_class, *args)
    command = command_class.new(args)
    allow(command).to receive(:ui).and_return(ui)
    command
  end

  def mock_chef_server_response(endpoint, response)
    allow(rest_client).to receive(:get)
      .with(endpoint)
      .and_return(response)
  end
end

RSpec.configure do |config|
  config.include KnifeHelpers
end
```

### Error Handling Best Practices
```ruby
def run
  validate_name_args!
  
  begin
    result = perform_operation
    output_result(result)
  rescue Net::HTTPClientException => e
    handle_http_error(e)
  rescue StandardError => e
    handle_general_error(e)
  end
end

private

def handle_http_error(error)
  case error.response.code
  when "404"
    ui.fatal("Resource not found")
  when "401", "403"  
    ui.fatal("Authentication failed")
  else
    ui.fatal("Server error: #{error.message}")
  end
  exit(1)
end
```

## Build Environment Setup

### Local Development Setup
```bash
# Clone repository
git clone https://github.com/chef/knife.git
cd knife

# Install Ruby dependencies
bundle install

# Run tests to verify setup
bundle exec rake spec

# Build gem locally
rake build

# Install development version
gem install pkg/knife-*.gem

# Verify installation
knife --version
```

### Docker Development Environment
```bash
# Build development container (if Dockerfile exists)
docker build -t knife-dev .

# Run tests in container
docker run --rm knife-dev bundle exec rake spec

# Interactive development shell
docker run -it --rm -v $(pwd):/app knife-dev bash
```

### Habitat Development
```bash
# Install Habitat CLI
curl https://raw.githubusercontent.com/habitat-sh/habitat/main/components/hab/install.sh | sudo bash

# Enter Habitat studio
hab studio enter

# Build package in studio
build

# Run tests against built package
hab pkg exec chef/knife spec
```

## Important Notes for GitHub Copilot

### Critical Reminders
- **ALL work is performed locally** - Never suggest cloud-based solutions
- **>80% test coverage is MANDATORY** - Cannot be compromised under any circumstances  
- **DCO signoff is REQUIRED** - All commits must include `--signoff` flag
- **Phase-based development** - Always wait for approval between phases
- **Comprehensive testing** - Test positive, negative, and edge cases
- **Use established patterns** - Follow existing code structure and conventions

### When to Ask for Clarification
- Requirements are ambiguous or incomplete
- Multiple implementation approaches are viable
- Changes might affect core functionality
- Additional context needed for testing scenarios
- Uncertain about integration points or dependencies

### Files Never to Modify
- Auto-generated files (VERSION, CHANGELOG.md, Gemfile.lock)
- CI/CD configuration without coordination
- Core application entry points without careful consideration
- Third-party vendor files

### Performance Considerations  
- Mock external API calls in tests
- Use efficient algorithms for data processing
- Consider memory usage for large datasets
- Implement proper cleanup in tests
- Profile performance-critical code paths

This comprehensive guide ensures that GitHub Copilot will follow established patterns, maintain code quality, achieve testing requirements, comply with DCO standards, and integrate properly with the existing build and release infrastructure.
