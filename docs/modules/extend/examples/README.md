# About

This directory contains source code examples that demonstrate how to
extend asciidoctor-pdf capabilities with custom Ruby code.

# Usage

For example, asciidoctor-pdf doesn't support by defaul the ability to
theme the admonitions per type.

This repository includes the Ruby code file [pdf-converter-admonition-theme-per-type.rb](./pdf-converter-admonition-theme-per-type.rb)
to allow you to theme admonitions per type, such as:

```yaml
admonition:
  text-align: left
  column-rule-color: #eeeeee
  column-rule-width: 0.5
  
admonition_tip:
  background-color: #ede8fa
  border-color: #872de6
  text-align: left
  border-radius: 3
  border-style: dashed
  font-kerning: none
  padding: 0.3cm
```

Then, to apply the custom theming as part of the PDF generation,
you need to instruct the `asciidoctor-pdf` command line tool to load
the Ruby extension using the `-r` command line argument which 
references the local extension Ruby file once you downloaded it
and made it available on disk:

```
$ asciidoctor-pdf \
    -r ./themes/pdf-converter-admonition-theme-per-type.rb \
    -a pdf-themesdir=./themes \
    -a pdf-theme="basic" \
    -D ./output \
    ./book/index.adoc
```

