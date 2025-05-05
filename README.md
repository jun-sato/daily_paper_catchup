# Paper Catchup

Paper Catchup is a free and high-accuracy system that automatically collects and summarizes scientific papers from journals like Nature and Lancet based on your interests. It runs daily at 3 AM, searches for relevant papers, downloads PDFs when available, creates text files with summaries, and can send notifications to Slack.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **Free to use**: Uses only free APIs and tools
- **Customizable**: Configure your topics of interest, target journals, and more
- **Automatic scheduling**: Runs daily at 3 AM
- **PDF download**: Attempts to download open access PDFs when available
- **Structured summaries**: Creates summaries with sections for what was done, key findings, novelty, potential applications, and limitations
- **Organized storage**: Stores papers and summaries in a structured directory hierarchy

## Setup

The easiest way to set up Paper Catchup is to use the installation script:

```bash
./install.sh
```

This script will:
1. Check for required dependencies
2. Make all scripts executable
3. Allow you to customize the configuration
4. Set up the scheduler if desired
5. Run a test to make sure everything is working

Alternatively, you can set up manually:

1. **Configure your interests**:
   Edit the `data/config.json` file to specify your topics of interest, target journals, and other settings.

   ```json
   {
     "journals": [
       "nature",
       "lancet",
       "science",
       "cell",
       "nejm"
     ],
     "topics": [
       "artificial intelligence",
       "machine learning",
       "climate change",
       "immunotherapy"
     ],
     "search_settings": {
       "days_back": 7,
       "max_papers_per_topic": 3,
       "min_relevance_score": 0.7
     },
     "schedule": {
       "time": "03:00"
     },
     "output_format": {
       "summary_sections": [
         "What was done",
         "Key findings",
         "Novelty",
         "Potential applications",
         "Limitations"
       ],
       "summary_length": "medium"
     }
   }
   ```

2. **Set up the scheduler**:
   Run the setup script to configure the system to run daily at 3 AM:

   ```bash
   ./scripts/setup_scheduler.sh
   ```

## Usage

### Running manually

You can run the system manually at any time:

```bash
./scripts/paper_catchup.sh
```

For convenience, you can also use the run_and_view.sh script, which runs the system and then immediately displays the results:

```bash
./scripts/run_and_view.sh
```

This is useful when you want to quickly check for new papers and view them in one step.

### Viewing collected papers

To view and browse the papers that have been collected, use the view_papers.sh script:

```bash
./scripts/view_papers.sh [days]
```

Where `[days]` is an optional parameter to filter papers from the last N days. If not provided, all papers will be listed.

This script will:
1. List all collected papers with their titles, journals, and topics
2. Allow you to select a paper to view its summary
3. If a PDF is available, give you the option to open it

### Viewing results

After running, the system will create a directory structure in the `downloads` directory:

```
downloads/
  └── YYYY-MM-DD_topic_name/
      └── PMID/
          ├── paper.pdf (if available)
          ├── summary.md
          └── metadata.json
```

Each paper will have its own directory named with its PubMed ID (PMID), containing:
- The PDF of the paper (if available)
- A summary file in Markdown format
- A metadata file with details about the paper

### Summary format

The summary file includes:

1. **Basic Information**: Title, journal, date, authors, DOI, topic, and PDF availability
2. **Abstract**: The full abstract of the paper
3. **Summary**:
   - What was done
   - Key findings
   - Novelty
   - Potential applications
   - Limitations

## Slack Notifications

Paper Catchup can send notifications to Slack when new papers are found. To set up Slack notifications:

1. Create a Slack app and webhook URL:
   - Go to https://api.slack.com/apps
   - Click "Create New App" and choose "From scratch"
   - Name your app (e.g., "Paper Catchup") and select your workspace
   - In the left sidebar, click on "Incoming Webhooks"
   - Toggle "Activate Incoming Webhooks" to On
   - Click "Add New Webhook to Workspace"
   - Select the channel where you want to receive notifications
   - Copy the webhook URL

2. Configure Slack notifications:
   - Edit the `data/slack_config.json` file:
   ```json
   {
     "webhook_url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
     "channel": "#paper-catchup",
     "username": "Paper Catchup Bot",
     "icon_emoji": ":books:",
     "max_papers_per_notification": 5
   }
   ```
   - Replace `"https://hooks.slack.com/services/YOUR/WEBHOOK/URL"` with your actual webhook URL

3. Test Slack notifications:
   ```bash
   ./scripts/slack_notify.sh
   ```

The notifications include:
- Paper title and journal
- Topic it was found under
- What was done in the research
- Key findings
- Novelty
- Link to the paper (if DOI is available)
- PDF availability status

## Customization

### Adding or changing topics

Edit the `topics` array in `data/config.json` to add or change your topics of interest.

### Adding or changing journals

Edit the `journals` array in `data/config.json` to add or change the journals you want to search.

### Changing search settings

Edit the `search_settings` object in `data/config.json` to change:
- `days_back`: How many days back to search for papers
- `max_papers_per_topic`: Maximum number of papers to retrieve per topic
- `min_relevance_score`: Minimum relevance score for papers (0.0-1.0)

### Changing the schedule

Edit the `schedule` object in `data/config.json` to change the time when the system runs.

To update the scheduler after changing the time, run:

```bash
./scripts/setup_scheduler.sh
```

## Maintenance

### Updating the system

If you need to update the system or ensure all components are working correctly, use the update_system.sh script:

```bash
./scripts/update_system.sh
```

This script will:
1. Backup your current configuration
2. Update the configuration format if needed
3. Make all scripts executable
4. Update the scheduler if requested

### Backing up your configuration

The update script automatically backs up your configuration to `data/backups/` with a timestamp. You can restore a backup by copying it back to `data/config.json`.

## Troubleshooting

### Logs

Check the log file at `data/paper_catchup.log` for information about the system's operation and any errors that occurred.

### Common issues

1. **No papers found**: Make sure your topics and journals are correctly specified. Try broadening your topics or increasing the `days_back` value.

2. **No PDFs downloaded**: Not all papers have open access PDFs available. The system will still create summaries based on the abstract.

3. **Scheduler not working**: Verify that the cron job is set up correctly by running `crontab -l`. Make sure your computer is on at the scheduled time.

## How it works

1. The system reads your configuration from `data/config.json`
2. For each topic and journal combination, it searches PubMed using the E-utilities API
3. For each paper found, it retrieves the details and abstract
4. It attempts to find an open access PDF using the Unpaywall API
5. It creates a summary based on the abstract, using pattern matching to extract key information
6. It organizes everything in a structured directory hierarchy

## Limitations

- The system relies on free APIs, which may have rate limits or usage restrictions
- Summaries are generated based on the abstract only, not the full text
- PDF availability depends on open access status
- The system uses basic pattern matching for summarization, not advanced AI

## GitHub Repository

This project is available as a GitHub repository, making it easy to install and update on any computer, including Linux systems. To use the GitHub repository:

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/paper-catchup.git
   cd paper-catchup
   ```

2. Run the installation script:
   ```bash
   ./install.sh
   ```

3. Customize the configuration as needed.

### Contributing

Contributions are welcome! If you'd like to contribute to Paper Catchup, please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Future improvements

- Add support for more paper sources
- Improve summarization techniques
- Add a web interface for browsing papers
- Implement full-text analysis for better summaries
- Support for more notification platforms (email, Discord, etc.)
