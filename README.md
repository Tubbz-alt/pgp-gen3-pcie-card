# pgp-gen3-pcie-card

# Before you clone the GIT repository

1) Create a github account:
> https://github.com/

2) On the Linux machine that you will clone the github from, generate a SSH key (if not already done)
> https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/

3) Add a new SSH key to your GitHub account
> https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/

4) Setup for large filesystems on github
> $ git lfs install

# Clone the GIT repository
> $ git clone --recursive git@github.com:slaclab/pgp-gen3-pcie-card

---------------------------------------------------------------------------
Notes on CameraLink interface:

Here are the three projects for the PgpG3 based base-mode Cameralink
framegrabber:

PgpCardG3_CLinkBase        -- 2.50 Gbps MGT, LCLS-I EVR, for fast/large pixel
                              count cameras, use with RCX blink-codes 1:3
                              (<= 60 MHz pixel clocks), and 1:4 (> 60 MHz)

PgpCardG3_CLinkBase_1p250  -- 1.25 Gbps MGT, LCLS-I EVR, for slow/small pixel
                              count cameras, use with RCX blink-codes 1:1 and
                              1:2 (<= 40 MHz usually; these 2 blink codes
                              are really exactly the same)

PgpCardG3_CLinkBaseII      -- 2.50 Gbps MGT, LCLS-II EVR, for fast/large pixel 
                              count cameras, use with RCX blink-codes 1:3
                              (<= 60 MHz pixel clocks), and 1:4 (> 60 MHz)

The difference between "CLinkBase" and "CLinkBase_1p250" is only the MGT
frequency, 125 MHz vs 62.5 MHz (all 8 channels).  In fact the 2.50 Gbps
"CLinkBase" can handle slow/small cameras as long as the RCX is set to 1:3.
So in locations where we have a mixed large/small cameras, we could mix
them on one board.  But in locations where we have only small cameras, it
is preferrable to use the 1.25 Gbps firmware (with RCX blink code 1:2), so
that the clocks are only at half the speed.  Up till now, there is no known
serious issue with these 2. -- It would be handy to have a bit to set, to
be able to self-generate triggers, for times when the EVG is not available
(never thought about this in the beginning, should be very easy to add).

