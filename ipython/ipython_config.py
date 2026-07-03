import datetime as dt
from pathlib import Path

# The name of the logfile to use.
logfile_dir = Path('~/projects/ipython-logs').expanduser()
logfile_dir.mkdir(parents=True, exist_ok=True)
now = dt.datetime.now().astimezone()
logfile_fn = logfile_dir / f'automatic-log--{now:%Y-%m-%dT%H-%M-%Z}.py'
# make sure file exists
logfile_fn.touch()

# set the logfile
c.TerminalInteractiveShell.logfile = logfile_fn


# Start logging to the default log file.
c.TerminalInteractiveShell.logstart = True
