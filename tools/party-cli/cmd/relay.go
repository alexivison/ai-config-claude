package cmd

import (
	"fmt"
	"os"

	"github.com/anthropics/ai-config/tools/party-cli/internal/message"
	"github.com/anthropics/ai-config/tools/party-cli/internal/state"
	"github.com/anthropics/ai-config/tools/party-cli/internal/tmux"
	"github.com/spf13/cobra"
)

func newRelayCmd(store *state.Store, client *tmux.Client) *cobra.Command {
	var wizard bool
	var filePath string

	cmd := &cobra.Command{
		Use:   "relay <worker-id> <message>",
		Short: "Send a message to a worker's Claude pane",
		Long: `Send a message to a worker's Claude pane (default) or Wizard pane (--wizard).

Use --file to send a file path pointer instead of inline text.`,
		Args: cobra.RangeArgs(1, 2),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()
			svc := message.NewService(store, client)

			// --file mode: relay a file pointer to a worker.
			if filePath != "" {
				if len(args) < 1 {
					return fmt.Errorf("--file requires a worker-id argument")
				}
				workerID := args[0]
				if _, err := os.Stat(filePath); err != nil {
					return fmt.Errorf("file %q not found: %w", filePath, err)
				}
				msg := "Read relay instructions at " + filePath
				if wizard {
					if err := svc.RelayToWizard(ctx, workerID, msg); err != nil {
						return err
					}
				} else {
					if err := svc.Relay(ctx, workerID, msg); err != nil {
						return err
					}
				}
				fmt.Fprintf(cmd.OutOrStdout(), "File pointer delivered to %s.\n", workerID)
				return nil
			}

			if len(args) < 2 {
				return fmt.Errorf("requires worker-id and message arguments")
			}
			workerID, msg := args[0], args[1]

			if wizard {
				if err := svc.RelayToWizard(ctx, workerID, msg); err != nil {
					return err
				}
				fmt.Fprintf(cmd.OutOrStdout(), "Sent to Wizard in %q.\n", workerID)
			} else {
				if err := svc.Relay(ctx, workerID, msg); err != nil {
					return err
				}
				fmt.Fprintf(cmd.OutOrStdout(), "Delivered to %s.\n", workerID)
			}
			return nil
		},
	}

	cmd.Flags().BoolVar(&wizard, "wizard", false, "send to the worker's Wizard (Codex) pane instead of Claude")
	cmd.Flags().StringVar(&filePath, "file", "", "send a file path pointer to the worker")

	return cmd
}
