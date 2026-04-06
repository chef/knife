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

Apache License, Version 2.0
