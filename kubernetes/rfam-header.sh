#!/bin/sh
#
#    00-header - create the header of the MOTD
#    Copyright (C) 2009-2010 Canonical Ltd.
#
#    Authors: Dustin Kirkland <kirkland@canonical.com>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

[ -r /etc/lsb-release ] && . /etc/lsb-release

if [ -z "$DISTRIB_DESCRIPTION" ] && [ -x /usr/bin/lsb_release ]; then
	# Fall back to using the very slow lsb_release utility
	DISTRIB_DESCRIPTION=$(lsb_release -s -d)
fi

#printf "Welcome to %s (%s %s %s)\n" "$DISTRIB_DESCRIPTION" "$(uname -o)" "$(uname -r)" "$(uname -m)"


printf "\n\n  ____    __\n"                   
printf " |  _ \\  / _|  __ _  _ __ ___\n"  
printf " | |_) || |_  / _\` || \`_ \` _ \\" 
printf "\n |  _ < |  _|| (_| || | | | | |\n"
printf " |_| \\_\\|_|   \\__,_||_| |_| |_|\n"

printf "\n\n Welcome to the Rfam cloud curation pipeline!\n\n"