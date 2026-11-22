#!/bin/bash
# Stable source directory name, so ccache hits survive a version bump.
#
# ccache hashes the preprocessed text, and the name of the unpacked tree
# (foo-1.2.3) sits in every relative -I path and line marker. A bump to
# foo-1.2.4 therefore misses on every file, changed or not (measured on
# qtwebengine 6.11.2 -> 6.11.3: 403 misses of 403). CCACHE_BASEDIR (set by
# 50-ccache.sh) only rewrites absolute paths, so the name has to stay put.
#
# Opt-in per package: XP_SRCDIR_NOVER=1 through package.env
# (env/srcdir-nover.conf). Before src_prepare the first directory below
# WORKDIR that leads to S is renamed to a name that never changes again, a
# symlink keeps the original name alive, and S points at the stable one in
# every later phase.
#
# The stable name is chosen once per cat/pkg:slot and kept in
# ${CCACHE_DIR}/srcdir-names (one "key name" line each, shared by everything
# that shares the cache):
#   - a version of the package is installed: the name THAT version unpacked
#     to (foo-1.2.3), so the entries its build left in the cache are hit by
#     the very next bump - no cold build to pay for switching the hook on;
#   - otherwise the name with the version cut out (foo).
# To start a package afresh delete its line. Live -9999 ebuilds are skipped:
# their name is constant already.
SrcdirNover() {
	BashrcdTrue "${XP_SRCDIR_NOVER-}" || return 0
	[[ ${PV} != *9999* ]] || return 0
	[[ -n ${S-} && -n ${WORKDIR-} && ${S} == "${WORKDIR}"/* ]] || return 0
	local sub=${S#"${WORKDIR}"/} top new old marker=${WORKDIR}/.srcdir-nover
	local key=${CATEGORY}/${PN}:${SLOT%/*} state=${CCACHE_DIR:+${CCACHE_DIR}/srcdir-names}
	top=${sub%%/*}
	if [[ -s ${marker} ]]
	then	new=$(<"${marker}")
	else	[[ ${EBUILD_PHASE} == prepare ]] || return 0
		new=
		[[ -n ${state} && -r ${state} ]] && \
			new=$(awk -v k="${key}" '$1 == k { n = $2 } END { print n }' "${state}")
		if [[ -z ${new} ]]
		then	old=$(best_version "${key}" 2>/dev/null)
			old=${old#"${CATEGORY}/${PN}-"}
			old=${old%-r[0-9]*}
			if [[ -n ${old} && ${old} != *9999* && ${top} == *"${PV}"* ]]
			then	new=${top//${PV}/${old}}
			else	# 1. cut ${PV} out (also without its _suffix); 2. otherwise cut
				#    from the first name segment that starts with a digit
				#    (boost_1_90_0)
				new=${top//${PV}/}
				[[ ${new} != "${top}" ]] || new=${top//${PV%%_*}/}
				if [[ ${new} == "${top}" && ${top} =~ ^([A-Za-z][A-Za-z0-9+]*([-_][A-Za-z][A-Za-z0-9+]*)*)[-_][0-9] ]]
				then	new=${BASH_REMATCH[1]}
				fi
				new=${new//--/-}
				new=${new%.src}
				new=${new%[-_.]}
			fi
			[[ -n ${new} ]] || return 0
			if [[ -n ${state} && -w ${CCACHE_DIR} ]]
			then	printf '%s %s\n' "${key}" "${new}" >> "${state}"
			fi
		fi
		[[ ${new} != "${top}" ]] || return 0
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
