# Stamp: A Quarto Extension for Document Information 

The Stamp extension for Quarto automatically adds detailed document information to your Quarto documents about how it was created. This includes system information, Quarto environment variables, document properties, project properties, session information, and a list of installed extensions.

## Installation

To install the `{quarto-stamp}` extension, follow these steps:

1.    Open your terminal.
2.    Navigate to your Quarto project directory.
3.    Run the following command:

```bash
quarto add coatless-quarto/stamp
```

This will install the extension under the `_extensions` subdirectory. If you're using version control, you will want to check in this directory.

### Requirements

- Quarto version >=1.6.0
- Python (optional, for version detection)
- R (optional, for version detection)

## Usage

Add the extension to your document or project:

```yaml
---
title: "My Document"
format: html
filters:
  - stamp
---
```

By default, the extension adds minimal document information at the bottom of your document. You can customize this behavior using the following options in your YAML front matter:

```yaml
---
stamp:
  # Choose information level: minimal, full
  level: full
  
  # Specify placement: bottom (default), top, or custom
  placement: bottom
  
  # For custom placement, specify the div id to replace
  placement-id: my-custom-div
  
  # Add specific sections beyond the level setting
  sections: 
    - environment
    - extensions
  
  # Control how sections are combined: add (default) or replace
  mode: add
---
```


### Configuration Options

| Option         | Values                                                                            | Default                | Description                                             |
|----------------|-----------------------------------------------------------------------------------|------------------------|---------------------------------------------------------|
| `level`        | `minimal`, `full`, `default`                                                      | `minimal`              | Sets the base level of information to include           |
| `placement`    | `bottom`, `top`, `custom`                                                         | `bottom`               | Controls where the information appears in the document  |
| `placement-id` | any string                                                                        | `document-information` | ID of the div to replace when using custom placement    |
| `sections`     | Array of: `system`, `environment`, `document`, `project`, `session`, `extensions` | none                   | Additional sections to include beyond the level setting |
| `mode`         | `add`, `replace`                                                                  | `add`                  | Controls how `sections` combines with the level setting |


## Information Sections

The extension can include the following sections:

- **System Information**: OS and Lua version
- **Quarto Environment Variables**: QUARTO_ROOT, QUARTO_SHARE_PATH, QUARTO_BIN_PATH
- **Document Properties**: Input file, output file, format, render tools
- **Project Properties**: Directory, output directory, render tools
- **Session Information**: Versions of Quarto, Pandoc, R, and Python
- **Extensions**: List of installed Quarto extensions with versions

## Information Levels

The extension supports two predefined information levels:

- **minimal** (default): Includes system and session information
- **full**: Includes all available sections

## Customizing Section Display

You can control which sections appear using the `sections` option:

```yaml
---
stamp:
  # Add specific sections to the minimal set
  sections: 
    - environment
    - extensions
  mode: add

  # Or replace with only specified sections
  sections:
    - system
    - extensions
  mode: replace
---
```

## Custom Placement

To place the document information at a specific location:

1. Set `placement: custom` in your YAML front matter
2. Add a div with your chosen ID in your document
3. Specify that ID in `placement-id`

```yaml
---
stamp:
  placement: custom
  placement-id: my-info-section
---

# My Document

::: {#my-info-section}
:::
```

## Acknowledgements

We would like to thank the developers of the `tinyyaml` library for providing a simple and efficient way to parse YAML front matter in Lua. Specifically, we would like to thank the maintainer of the fork, [`@api7`](https://https://github.com/api7/lua-tinyyaml), and the author of the original implementation [`@peposso`](https://github.com/peposso/lua-tinyyaml).
The `tinyyaml` library is available under the MIT license and can be found at 

### Notes

This extension is inspired by the [`sessioninfo`](https://sessioninfo.r-lib.org/) package for R. It is designed to provide detailed information about the document and the environment in which it was created to aid with creating reproducible examples (reprex). We previously discussed the idea of a "document stamp" in the [Quarto discussion forums](https://github.com/quarto-dev/quarto-cli/discussions/8559).

We hope it will be useful for debugging and reproducibility.
