#!/bin/bash
# Version-less source directory, so ccache hits survive a version bump.
#
# ccache hashes the preprocessed text, and the name of the unpacked tree
# (foo-1.2.3) sits in every relative -I path and line marker. A bump to
# foo-1.2.4 therefore misses on every file, changed or not (measured on
# qtwebengine 6.11.2 -> 6.11.3: 403 misses of 403). CCACHE_BASEDIR (set by
# 50-ccache.sh) only rewrites absolute paths, so the name has to go.
#
# Opt-in per package: XP_SRCDIR_NOVER=1 through package.env
# (env/srcdir-nover.conf). Before src_prepare the first directory below
# WORKDIR that leads to S is renamed with ${PV} cut out, a symlink keeps the
# old name alive, and S points at the new one in every later phase.
# Skipped when the name carries no version (live -9999 ebuilds).
SrcdirNover() {
	BashrcdTrue "${XP_SRCDIR_NOVER-}" || return 0
	[[ ${PV} != *9999* ]] || return 0
	[[ -n ${S-} && -n ${WORKDIR-} && ${S} == "${WORKDIR}"/* ]] || return 0
	local sub=${S#"${WORKDIR}"/} top new marker=${WORKDIR}/.srcdir-nover
	top=${sub%%/*}
	if [[ -s ${marker} ]]
	then	new=$(<"${marker}")
	else	[[ ${EBUILD_PHASE} == prepare ]] || return 0
		# 1. cut ${PV} out (also without its _suffix); 2. otherwise cut from
		#    the first name segment that starts with a digit (boost_1_90_0)
		new=${top//${PV}/}
		[[ ${new} != "${top}" ]] || new=${top//${PV%%_*}/}
		if [[ ${new} == "${top}" && ${top} =~ ^([A-Za-z][A-Za-z0-9+]*([-_][A-Za-z][A-Za-z0-9+]*)*)[-_][0-9] ]]
		then	new=${BASH_REMATCH[1]}
		fi
		new=${new//--/-}
		new=${new%.src}
		new=${new%[-_.]}
		[[ -n ${new} && ${new} != "${top}" ]] || return 0
		[[ -d ${WORKDIR}/${top} && ! -L ${WORKDIR}/${top} && ! -e ${WORKDIR}/${new} ]] || return 0
		mv -- "${WORKDIR}/${top}" "${WORKDIR}/${new}" || die "srcdir-nover: rename failed"
		ln -s -- "${new}" "${WORKDIR}/${top}" || die "srcdir-nover: symlink failed"
		printf '%s\n' "${new}" > "${marker}"
		BashrcdEcho "srcdir-nover: ${top} -> ${new}"
	fi
	[[ -d ${WORKDIR}/${new} ]] || return 0
	S=${WORKDIR}/${new}${sub#"${top}"}
}

BashrcdPhase prepare SrcdirNover
BashrcdPhase configure SrcdirNover
BashrcdPhase compile SrcdirNover
BashrcdPhase test SrcdirNover
BashrcdPhase install SrcdirNover
