# docs

Please analyze project and generate documentation for the project.
- first an high-level overview for the architecture, and then drill down to each package.
- The generated markdown files should be put into folder local/docs
- use mermaid for visualization
- do not hallucinate, strickly stick to the implemenation

# site

use the content at local/docs generate a static site using https://gohugo.io/documentation/,
- the site should be in local/site folder
- convert the mermaid file to svg, if there are errors during conversion, fix the source if possible
- mmdc command is already installed, just use it
- the helper scripts should be put in local/site/scripts folder
- should have a Makefile for common targets
- do not use linenumbers for code block
- use the hash of the content of mermaid content as the postfix of name for the svg file
- must use generated svg in the page to shorten the page load time
- the navigation among pages inside the site should work
- should have a toggle to switch between light/dark mode
- should have a toggle to expand/fold menu (collapsed to icon bar with tooltips)
- the width of the menu and content should be adjustable (drag the divider line between menu and content)
- add a Dockerfile to package public folder, and use `python3 -m http.server` as servicing engine
- use http port 9006 for the site
- do not modify workbook.md
