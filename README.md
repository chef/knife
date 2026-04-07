# Knife

Knife is a command-line tool that provides an interface between a local Chef repository and the Chef Infra Server.

## Installation

```bash
gem install knife
```

## Quick Start

```bash
# Configure knife
knife configure

# List nodes
knife node list

# Upload a cookbook
knife cookbook upload COOKBOOK_NAME

# Bootstrap a node
knife bootstrap HOST -U USER -i IDENTITY_FILE --node-name NODE_NAME
```

## Documentation

- [Official Knife Documentation](https://docs.chef.io/workstation/knife/)
- [Setting up Knife](https://docs.chef.io/workstation/knife_setup/)
- [Developer's Guide](docs/dev/README.md)

## Contributing

See the [Developer's Guide](docs/dev/README.md) for development setup and guidelines.

## License

```
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
