package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/spf13/cobra/doc"
)

// docsCmd generates the command-tree reference — man pages or markdown — the
// artifacts an installer ships next to the binary (`make man`, a package, a
// Homebrew formula). It renders the passed root, so the docs can never drift
// from the shipped surface.
func docsCmd(root *cobra.Command) *cobra.Command {
	c := &cobra.Command{
		Use:   "docs",
		Short: "Generate the command reference (man pages or markdown)",
		Long: `Generate the full command reference from the live command tree:
man pages (--format man, one page per command, section 1) or a markdown
tree (--format markdown). Written into --dir; see also 'baseproof
completion <shell>' for the matching shell completions.`,
		Args: cobra.NoArgs,
	}
	dir := c.Flags().String("dir", "docs", "write the generated files into this directory")
	format := c.Flags().String("format", "man", "output format: man | markdown")
	c.RunE = func(cmd *cobra.Command, _ []string) error {
		if err := os.MkdirAll(*dir, 0o755); err != nil {
			return err
		}
		switch *format {
		case "man":
			hdr := &doc.GenManHeader{Title: "BASEPROOF", Section: "1", Source: "baseproof " + version}
			return doc.GenManTree(root, hdr, *dir)
		case "markdown":
			return doc.GenMarkdownTree(root, *dir)
		default:
			return fmt.Errorf("unknown --format %q (want man or markdown)", *format)
		}
	}
	return c
}
