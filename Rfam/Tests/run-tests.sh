for t in \
    bio_rfam_clan_desc.t \
    bio_rfam_config.t \
    bio_rfam_family_cm.t \
    bio_rfam_family_desc.t \
    bio_rfam_familyio.t \
    bio_rfam_family_msa.t \
    bio_rfam_family_scores.t \
    bio_rfam_family.t \
    bio_rfam_family_tblout.t \
    bio_rfam_htmlalignment.t \
    bio_rfam_infernal.t \
    bio_rfam_pair.t \
    bio_rfam_qc.t \
    bio_rfam_seqdb.t \
    bio_rfam_ss.t \
    bio_rfam_svn_client.t \
    bio_rfam_svn_commit.t \
    bio_rfam_view.t \
    rfmake.t \
    rfmatch.t \
    rfseed-extend.t \
; do 
    prove $t
done
