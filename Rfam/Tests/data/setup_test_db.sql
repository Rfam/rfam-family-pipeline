-- Rfam CI test database setup
-- Subset of rfamlive schema with real NCBI taxonomy IDs from rfamlive live DB
-- (mysql-rfam-public.ebi.ac.uk:4497, database Rfam, user rfamro).
-- Contains minimal data for bio_rfam_family_msa.t (RF00014) and
-- bio_rfam_htmlalignment.t (RF00504).

-- Drop existing tables (in dependency order)
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS seed_region;
DROP TABLE IF EXISTS full_region;
DROP TABLE IF EXISTS rfamseq;
DROP TABLE IF EXISTS taxonomy;
DROP TABLE IF EXISTS family;
SET FOREIGN_KEY_CHECKS = 1;

-- ── Tables ──────────────────────────────────────────────────────────
-- Column types sourced from RfamLive DBIC schema modules.

CREATE TABLE taxonomy (
    ncbi_id           INT UNSIGNED NOT NULL DEFAULT 0,
    species           VARCHAR(100) NOT NULL DEFAULT '',
    tax_string        MEDIUMTEXT,
    tree_display_name VARCHAR(100),
    align_display_name VARCHAR(50),
    PRIMARY KEY (ncbi_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE rfamseq (
    rfamseq_acc       VARCHAR(20) NOT NULL DEFAULT '',
    accession         VARCHAR(15) NOT NULL,
    version           INT NOT NULL,
    ncbi_id           INT UNSIGNED NOT NULL,
    mol_type          ENUM('protein','genomic DNA','DNA','ss-DNA','RNA','genomic RNA','ds-RNA','ss-cRNA','ss-RNA','mRNA','tRNA','rRNA','snoRNA','snRNA','scRNA','pre-RNA','other RNA','other DNA','unassigned DNA','unassigned RNA','viral cRNA','cRNA','transcribed RNA') NOT NULL,
    length            INT UNSIGNED DEFAULT 0,
    description       VARCHAR(250) NOT NULL DEFAULT '',
    previous_acc      MEDIUMTEXT,
    source            CHAR(20) NOT NULL DEFAULT '',
    PRIMARY KEY (rfamseq_acc),
    KEY ncbi_id (ncbi_id),
    CONSTRAINT fk_rfamseq_taxonomy FOREIGN KEY (ncbi_id) REFERENCES taxonomy(ncbi_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE family (
    rfam_acc          VARCHAR(7) NOT NULL,
    rfam_id           VARCHAR(40) NOT NULL,
    auto_wiki         INT UNSIGNED NOT NULL,
    description       VARCHAR(75),
    author            TINYTEXT,
    seed_source       TINYTEXT,
    gathering_cutoff  DOUBLE(5,2),
    trusted_cutoff    DOUBLE(5,2),
    noise_cutoff      DOUBLE(5,2),
    comment           LONGTEXT,
    previous_id       TINYTEXT,
    cmbuild           TINYTEXT,
    cmcalibrate       TINYTEXT,
    cmsearch          TINYTEXT,
    num_seed          BIGINT,
    num_full          BIGINT,
    num_genome_seq    BIGINT,
    num_refseq        BIGINT,
    type              VARCHAR(50),
    structure_source  TINYTEXT,
    number_of_species BIGINT,
    number_3d_structures INTEGER,
    tax_seed          MEDIUMTEXT,
    ecmli_lambda      DOUBLE(10,5),
    ecmli_mu          DOUBLE(10,5),
    ecmli_cal_db      MEDIUMINT DEFAULT 0,
    ecmli_cal_hits    MEDIUMINT DEFAULT 0,
    maxl              MEDIUMINT DEFAULT 0,
    clen              MEDIUMINT DEFAULT 0,
    match_pair_node   TINYINT DEFAULT 0,
    hmm_tau           DOUBLE(10,5),
    hmm_lambda        DOUBLE(10,5),
    created           DATETIME NOT NULL,
    updated           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (rfam_acc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE full_region (
    rfam_acc          VARCHAR(7) NOT NULL,
    rfamseq_acc       VARCHAR(20) NOT NULL,
    seq_start         BIGINT UNSIGNED NOT NULL DEFAULT 0,
    seq_end           BIGINT UNSIGNED NOT NULL,
    bit_score         DOUBLE(7,2) NOT NULL DEFAULT 0.00,
    evalue_score      VARCHAR(15) NOT NULL DEFAULT '0',
    cm_start          MEDIUMINT UNSIGNED NOT NULL,
    cm_end            MEDIUMINT UNSIGNED NOT NULL,
    truncated         ENUM('0','5','3','53') NOT NULL DEFAULT '0',
    type              ENUM('seed','full') NOT NULL DEFAULT 'full',
    is_significant    TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (rfam_acc, rfamseq_acc, seq_start, seq_end, evalue_score),
    KEY rfamseq_acc (rfamseq_acc),
    CONSTRAINT fk_full_region_family FOREIGN KEY (rfam_acc) REFERENCES family(rfam_acc) ON DELETE CASCADE,
    CONSTRAINT fk_full_region_rfamseq FOREIGN KEY (rfamseq_acc) REFERENCES rfamseq(rfamseq_acc) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE seed_region (
    rfam_acc          VARCHAR(7) NOT NULL,
    rfamseq_acc       VARCHAR(20) NOT NULL,
    seq_start         BIGINT UNSIGNED NOT NULL DEFAULT 0,
    seq_end           BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (rfam_acc, rfamseq_acc),
    CONSTRAINT fk_seed_region_family FOREIGN KEY (rfam_acc) REFERENCES family(rfam_acc) ON DELETE CASCADE,
    CONSTRAINT fk_seed_region_rfamseq FOREIGN KEY (rfamseq_acc) REFERENCES rfamseq(rfamseq_acc) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Seed Data: Taxonomy ─────────────────────────────────────────────
-- Real align_display_name values from rfamlive. Some are truncated
-- to >50 chars in rfamlive (shown as ..), so we use the full name.

INSERT INTO taxonomy (ncbi_id, species, tax_string, tree_display_name, align_display_name) VALUES
(548,    'Enterobacter aerogenes',                  'Bacteria; Proteobacteria; Gammaproteobacteria; Enterobacteriales; Enterobacteriaceae; Enterobacter.', 'Enterobacter_aerogenes', 'Enterobacter_aerogenes[548]'),
(1423, 'Bacillus subtilis',                         'Bacteria; Firmicutes; Bacillales; Bacillaceae; Bacillus.', 'Bacillus_subtilis', 'Bacillus_subtilis[1423]'),
(1424, 'Bacillus subtilis',                         'Bacteria; Firmicutes; Bacillales; Bacillaceae; Bacillus.', 'Bacillus_subtilis', 'Bacillus_subtilis[1424]'),
(1639, 'Listeria monocytogenes',                    'Bacteria; Firmicutes; Bacillales; Listeriaceae; Listeria.', 'Listeria_monocytogenes', 'Listeria_monocytogenes[1639]'),
(1640, 'Listeria monocytogenes',                    'Bacteria; Firmicutes; Bacillales; Listeriaceae; Listeria.', 'Listeria_monocytogenes', 'Listeria_monocytogenes[1640]'),
(1642, 'Listeria innocua',                          'Bacteria; Firmicutes; Bacillales; Listeriaceae; Listeria.', 'Listeria_innocua', 'Listeria_innocua[1642]'),
(1731, 'Eubacterium acidaminophilum',               'Bacteria; Firmicutes; Clostridia; Clostridiales; Eubacteriaceae; Eubacterium.', 'Eubacterium_acidaminophilum', 'Eubacterium_acidaminophilum[1731]'),
(1828, 'Rhodococcus fascians',                      'Bacteria; Actinobacteria; Actinobacteridae; Actinomycetales; Corynebacterineae; Nocardiaceae; Rhodococcus.', 'Rhodococcus_fascians', 'Rhodococcus_fascians[1828]'),
(1902, 'Streptomyces coelicolor',                   'Bacteria; Actinobacteria; Actinobacteridae; Actinomycetales; Streptomycineae; Streptomycetaceae; Streptomyces.', 'Streptomyces_coelicolor', 'Streptomyces_coelicolor[1902]'),
(3832, 'Bartonella henselae',                       'Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Bartonellaceae; Bartonella.', 'Bartonella_henselae', 'Bartonella_henselae[3832]'),
(38323,'Bartonella henselae',                       'Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Bartonellaceae; Bartonella.', 'Bartonella_henselae', 'Bartonella_henselae[38323]'),
(62977,'Acinetobacter sp. ADP1',                    'Bacteria; Proteobacteria; Gammaproteobacteria; Pseudomonadales; Moraxellaceae; Acinetobacter.', 'Acinetobacter_sp._ADP1', 'Acinetobacter[62977]'),
(74109,'Photobacterium profundum',                  'Bacteria; Proteobacteria; Gammaproteobacteria; Vibrionales; Vibrionaceae; Photobacterium.', 'Photobacterium_profundum', 'Photobacterium_profundum[74109]'),
(83331,'Mycobacterium tuberculosis CDC1551',        'Bacteria; Actinobacteria; Actinobacteridae; Actinomycetales; Corynebacterineae; Mycobacteriaceae; Mycobacterium; Mycobacterium tuberculosis complex.', 'Mycobacterium_tuberculosis_CDC1551', 'Mycobacterium_tuberculosis[83331]'),
(83332,'Mycobacterium tuberculosis H37Rv',          'Bacteria; Actinobacteria; Actinobacteridae; Actinomycetales; Corynebacterineae; Mycobacteriaceae; Mycobacterium; Mycobacterium tuberculosis complex.', 'Mycobacterium_tuberculosis_H37Rv', 'Mycobacterium_tuberculosis[83332]'),
(177439,'Desulfotalea psychrophila LSv54',          'Bacteria; Proteobacteria; Deltaproteobacteria; Desulfobacterales; Desulfobulbaceae; Desulfotalea.', 'Desulfotalea_psychrophila_LSv54', 'Desulfotalea_psychrophila[177439]'),
(190485,'Xanthomonas campestris pv. campestris str. ATCC 33913', 'Bacteria; Proteobacteria; Gammaproteobacteria; Xanthomonadales; Xanthomonadaceae; Xanthomonas.', 'Xanthomonas_campestris_pv._campestris_str._ATCC_33913', 'Xanthomonas_campestris[190485]'),
(190486,'Xanthomonas axonopodis pv. citri str. 306', 'Bacteria; Proteobacteria; Gammaproteobacteria; Xanthomonadales; Xanthomonadaceae; Xanthomonas.', 'Xanthomonas_axonopodis_pv._citri_str._306', 'Xanthomonas_axonopodis[190486]'),
(204722,'Brucella suis 1330',                       'Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Brucellaceae; Brucella.', 'Brucella_suis_1330', 'Brucella_suis[204722]'),
(211110,'Streptococcus agalactiae NEM316',          'Bacteria; Firmicutes; Lactobacillales; Streptococcaceae; Streptococcus.', 'Streptococcus_agalactiae_NEM316', 'Streptococcus_agalactiae[211110]'),
(218491,'Pectobacterium atrosepticum SCRI1043',     'Bacteria; Proteobacteria; Gammaproteobacteria; Enterobacteriales; Enterobacteriaceae; Pectobacterium.', 'Pectobacterium_atrosepticum_SCRI1043', 'Pectobacterium_atrosepticum[218491]'),
(258594,'Rhodopseudomonas palustris CGA009',        'Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Bradyrhizobiaceae; Rhodopseudomonas.', 'Rhodopseudomonas_palustris_CGA009', 'Rhodopseudomonas_palustris[258594]'),
(266834,'Sinorhizobium meliloti 1021',              'Bacteria; Proteobacteria; Alphaproteobacteria; Rhizobiales; Rhizobiaceae; Sinorhizobium/Ensifer group; Sinorhizobium.', 'Sinorhizobium_meliloti_1021', 'Sinorhizobium_meliloti[266834]'),
(272843,'Pasteurella multocida subsp. multocida str. Pm70', 'Bacteria; Proteobacteria; Gammaproteobacteria; Pasteurellales; Pasteurellaceae; Pasteurella.', 'Pasteurella_multocida_subsp._multocida_str._Pm70', 'Pasteurella_multocida[272843]'),
(273068,'Thermoanaerobacter tengcongensis MB4',     'Bacteria; Firmicutes; Clostridia; Thermoanaerobacterales; Thermoanaerobacteraceae; Caldanaerobacter.', 'Thermoanaerobacter_tengcongensis_MB4', 'Thermoanaerobacter_tengcongensis[273068]'),
(281090,'Leifsonia xyli subsp. xyli str. CTCB07',   'Bacteria; Actinobacteria; Actinobacteridae; Actinomycetales; Micrococcineae; Microbacteriaceae; Leifsonia.', 'Leifsonia_xyli_subsp._xyli_str._CTCB07', 'Leifsonia_xyli[281090]'),
(281309,'Bacillus thuringiensis serovar konkukian str. 97-27', 'Bacteria; Firmicutes; Bacillales; Bacillaceae; Bacillus; Bacillus cereus group.', 'Bacillus_thuringiensis_serovar_konkukian_str._97-27', 'Bacillus_thuringiensis[281309]'),
(28915,'Bordetella bronchiseptica',                 'Bacteria; Proteobacteria; Gammaproteobacteria; Pasteurellales; Pasteurellaceae; Bordetella.', 'Bordetella_bronchiseptica', 'Bordetella_bronchiseptica[28915]'),
(370554,'Streptococcus pyogenes MGAS10750',         'Bacteria; Firmicutes; Lactobacillales; Streptococcaceae;Streptococcus.', 'Streptococcus_pyogenes_MGAS10750', 'Streptococcus_pyogenes[370554]'),
(399742,'Enterobacter sp. 638',                     'Bacteria; Proteobacteria; Gammaproteobacteria; Enterobacteriales; Enterobacteriaceae; Enterobacter.', 'Enterobacter_sp._638', 'Enterobacter[399742]'),
(405955,'Escherichia coli APEC O1',                 'Bacteria; Proteobacteria; Gammaproteobacteria; Enterobacteriales; Enterobacteriaceae; Escherichia.', 'Escherichia_coli_APEC_O1', 'Escherichia_coli_APEC_O1[405955]'),
(476213,'Salmonella enterica subsp. enterica serovar Paratyphi C strain RKS4594', 'Bacteria; Proteobacteria; Gammaproteobacteria; Enterobacteriales; Enterobacteriaceae; Salmonella; Salmonella enterica subsp. enterica serovar Paratyphi C.', 'Salmonella_enterica_subsp._enterica_serovar_Paratyphi_C_strain_RKS4594', 'Salmonella_enterica[476213]'),
(488222,'Streptococcus pneumoniae JJA',             'Bacteria; Firmicutes; Lactobacillales; Streptococcaceae; Streptococcus.', 'Streptococcus_pneumoniae_JJA', 'Streptococcus_pneumoniae[488222]'),
(591020,'Shigella flexneri 2002017',                'Bacteria; Proteobacteria; Gammaproteobacteria; Enterobacteriales; Enterobacteriaceae; Shigella.', 'Shigella_flexneri_2002017', 'Shigella_flexneri_2002017[591020]');

-- ── Seed Data: RF00014 rfamseq entries (5 seed sequences) ──────────
-- Real accession/version/description from rfamlive.

INSERT INTO rfamseq (rfamseq_acc, accession, version, ncbi_id, mol_type, length, description, source) VALUES
('M15749.1',    'M15749',    1, 548,    'genomic DNA', 405, 'K.aerogenes colanic acid capsular biosynthesis activation protein (rcsB) gene, complete cds.', 'EMBL;STD;PRO'),
('CP000653.1',  'CP000653',  1, 399742, 'genomic DNA', 4518712, 'Enterobacter sp. 638, complete genome.', 'EMBL;STD;PRO'),
('CP000468.1',  'CP000468',  1, 405955, 'genomic DNA', 5082025, 'Escherichia coli APEC O1, complete genome.', 'EMBL;STD;PRO'),
('CP000857.1',  'CP000857',  1, 476213, 'genomic DNA', 4833080, 'Salmonella enterica subsp. enterica serovar Paratyphi C strain RKS4594, complete genome.', 'EMBL;STD;PRO'),
('CP001383.1',  'CP001383',  1, 591020, 'genomic DNA', 4650856, 'Shigella flexneri 2002017, complete genome.', 'EMBL;STD;PRO');

-- ── Seed Data: RF00504 rfamseq entries (44 sequences, 29 unique) ──
-- Real accession/version/description from rfamlive.

INSERT INTO rfamseq (rfamseq_acc, accession, version, ncbi_id, mol_type, length, description, source) VALUES
('BX842577.1',  'BX842577',  1, 83332, 'genomic DNA', 344587, 'Mycobacterium tuberculosis H37Rv, complete genome.', 'EMBL;STD;PRO'),
('AE000516.2',  'AE000516',  2, 83332, 'genomic DNA', 79275,   'Mycobacterium tuberculosis H37Rv, complete genome.', 'EMBL;STD;PRO'),
('BX842572.1',  'BX842572',  1, 83332, 'genomic DNA', 79202,   'Mycobacterium tuberculosis H37Rv, complete genome.', 'EMBL;STD;PRO'),
('AJ301559.2',  'AJ301559',  2, 1828,  'genomic DNA', 7012,    'Ralstonia fascians R8270, complete genome.', 'EMBL;STD;PRO'),
('AE016822.1',  'AE016822',  1, 281090,'genomic DNA', 1714518, 'Leifsonia xyli subsp. xyli str. CTCB07, complete genome.', 'EMBL;STD;PRO'),
('AL939123.1',  'AL939123',  1, 1902,  'genomic DNA', 278145,  'Streptomyces coelicolor A3(2), complete genome.', 'EMBL;STD;PRO'),
('AL939108.1',  'AL939108',  1, 1902,  'genomic DNA', 255539,  'Streptomyces coelicolor A3(2), complete genome.', 'EMBL;STD;PRO'),
('D84432.1',    'D84432',    1, 1423,  'genomic DNA', 170100,  'Bacillus subtilis 168, complete genome.', 'EMBL;STD;PRO'),
('AE017355.1',  'AE017355',  1, 281309,'genomic DNA', 2242962, 'Bacillus thuringiensis serovar konkukian str. 97-27, complete genome.', 'EMBL;STD;PRO'),
('AL591978.1',  'AL591978',  1, 1640,  'genomic DNA', 212931,  'Listeria monocytogenes serotype 4b F2365, complete genome.', 'EMBL;STD;PRO'),
('AL596168.1',  'AL596168',  1, 1642,  'genomic DNA', 161717,  'Listeria innocua.clip.2.', 'EMBL;STD;PRO'),
('AJ312125.1',  'AJ312125',  1, 1731,  'genomic DNA', 523,     'Eubacterium acidaminophilum ATCC 8610.', 'EMBL;STD;PRO'),
('AE008691.1',  'AE008691',  1, 273068,'genomic DNA', 1826408, 'Thermoanaerobacter tengcongensis MB4, complete genome.', 'EMBL;STD;PRO'),
('AL766849.1',  'AL766849',  1, 211110,'genomic DNA', 65772,   'Streptococcus agalactiae NEM316, complete genome.', 'EMBL;STD;PRO'),
('CP000919.1',  'CP000919',  1, 488222,'genomic DNA', 381303,  'Streptococcus pneumoniae JJA, complete genome.', 'EMBL;STD;PRO'),
('CP000262.1',  'CP000262',  1, 370554,'genomic DNA', 1070913, 'Streptococcus pyogenes MGAS10750, complete genome.', 'EMBL;STD;PRO'),
('BX897699.1',  'BX897699',  1, 38323, 'genomic DNA', 1435970, 'Bartonella henselae Houston-1, complete genome.', 'EMBL;STD;PRO'),
('BX572605.1',  'BX572605',  1, 258594,'genomic DNA', 160849,  'Rhodopseudomonas palustris CGA009, complete genome.', 'EMBL;STD;PRO'),
('AE014292.2',  'AE014292',  2, 204722,'genomic DNA', 713320,  'Brucella suis 1330, complete genome.', 'EMBL;STD;PRO'),
('AL591688.1',  'AL591688',  1, 266834,'genomic DNA', 1674990, 'Sinorhizobium meliloti 1021, complete genome.', 'EMBL;STD;PRO'),
('BX640439.1',  'BX640439',  1, 28915, 'genomic DNA', 206535,  'Bordetella bronchiseptica RB50, complete genome.', 'EMBL;STD;PRO'),
('BX640445.1',  'BX640445',  1, 28915, 'genomic DNA', 160210,  'Bordetella bronchiseptica RB50, complete genome.', 'EMBL;STD;PRO'),
('CR522870.1',  'CR522870',  1, 177439,'genomic DNA', 1448793, 'Desulfotalea psychrophila LSv54, complete genome.', 'EMBL;STD;PRO'),
('BX950851.1',  'BX950851',  1, 218491,'genomic DNA', 2645260, 'Pectobacterium atrosepticum SCRI1043, complete genome.', 'EMBL;STD;PRO'),
('AE004439.1',  'AE004439',  1, 272843,'genomic DNA', 116172,  'Pasteurella multocida subsp. multocida str. Pm70, complete genome.', 'EMBL;STD;PRO'),
('CR543861.1',  'CR543861',  1, 62977, 'genomic DNA', 1990167, 'Acinetobacter sp. ADP1, complete genome.', 'EMBL;STD;PRO'),
('CR378670.1',  'CR378670',  1, 74109, 'genomic DNA', 15904,   'Photobacterium profundum SS9, complete genome.', 'EMBL;STD;PRO'),
('AE008922.1',  'AE008922',  1, 190485,'genomic DNA', 1299977, 'Xanthomonas campestris pv. campestris str. ATCC 33913, complete genome.', 'EMBL;STD;PRO'),
('AE008923.1',  'AE008923',  1, 190486,'genomic DNA', 1392465, 'Xanthomonas axonopodis pv. citri str. 306, complete genome.', 'EMBL;STD;PRO');

-- ── Seed Data: Family table ────────────────────────────────────────
-- Real gathering/trusted/noise cutoffs from rfamlive.

INSERT INTO family (rfam_acc, rfam_id, auto_wiki, description, gathering_cutoff, trusted_cutoff, noise_cutoff, num_seed, created, updated) VALUES
('RF00014', 'DsrA',     0, 'DsrA RNA',  60.00, 60.10, 59.20, 5,   NOW(), NOW()),
('RF00504', 'Glycine',  0, 'Glycine riboswitch aptamer', 32.00, 32.00, 31.90, 44, NOW(), NOW());

-- ── Seed Data: RF00014 full_region (seed type, for bio_rfam_family_msa.t) ──
-- Positions from RF00014 SEED file. Bit scores from real rfamlive full_region
-- where available; otherwise plausible values (GA=60, so >60 for seed).

INSERT INTO full_region (rfam_acc, rfamseq_acc, seq_start, seq_end, bit_score, evalue_score, cm_start, cm_end, truncated, type, is_significant) VALUES
('RF00014', 'M15749.1',    155,  239,   85.00, '1.0E-10', 1, 85, '0', 'seed',  1),
('RF00014', 'CP000653.1',  2739273, 2739189, 82.00, '2.0E-10', 1, 85, '0', 'seed',  1),
('RF00014', 'CP000468.1',  2032638, 2032552, 102.50, '8.4e-15', 1, 85, '0', 'seed',  1),
('RF00014', 'CP000857.1',  1802194, 1802277, 79.00, '5.0E-10', 1, 85, '0', 'seed',  1),
('RF00014', 'CP001383.1',  2080784, 2080698, 76.00, '1.0E-9', 1, 85, '0', 'seed',  1);

-- ── Seed Data: RF00504 full_region (for bio_rfam_htmlalignment.t) ──
-- Real rfamlive positions and bit scores for sequences that have them.
-- For sequences without real full_region in rfamlive, using seed_region
-- positions with plausible bit scores (32-40, above GA=32).
-- The HtmlAlignment test takes first() from FullRegion search per sequence,
-- so only one entry per (rfam_acc, rfamseq_acc) matters.

INSERT INTO full_region (rfam_acc, rfamseq_acc, seq_start, seq_end, bit_score, evalue_score, cm_start, cm_end, truncated, type, is_significant) VALUES
-- Sequences with real rfamlive full_region (9 unique sequences):
('RF00504', 'AE000516.2',  79275,   79185,   62.40, '8.4e-07', 1, 94, '0', 'full', 1),
('RF00504', 'AE004439.1',  116056,  116172,  64.90, '1.8e-07', 1, 94, '0', 'full', 1),
('RF00504', 'AE008691.1',  1826408, 1826307, 72.70, '1.6e-09', 1, 94, '0', 'full', 1),
('RF00504', 'AE008922.1',  1299900, 1299786, 65.60, '1.2e-07', 1, 94, '0', 'full', 1),
('RF00504', 'AE016822.1',  1714420, 1714518, 61.40, '1.5e-06', 1, 94, '0', 'full', 1),
('RF00504', 'AL591688.1',  1674906, 1674991, 62.30, '8.8e-07', 1, 94, '0', 'full', 1),
('RF00504', 'BX950851.1',  2645034, 2645129, 57.30, '1.9e-05', 1, 94, '0', 'full', 1),
('RF00504', 'CR522870.1',  1448610, 1448703, 56.70, '2.7e-05', 1, 94, '0', 'full', 1),
('RF00504', 'CR543861.1',  1990073, 1990167, 75.30, '3.3e-10', 1, 94, '0', 'full', 1),
-- Sequences without real full_region in rfamlive, using seed_region positions:
('RF00504', 'BX842577.1',  344457,  344587,  38.50, '5.0E-04', 1, 94, '0', 'full', 1),
('RF00504', 'BX842572.1',  79095,   79202,   37.20, '8.0E-04', 1, 94, '0', 'full', 1),
('RF00504', 'AJ301559.2',  6878,    7012,    36.50, '1.0E-03', 1, 94, '0', 'full', 1),
('RF00504', 'AL939123.1',  278052,  278145,  37.80, '6.0E-04', 1, 94, '0', 'full', 1),
('RF00504', 'AL939108.1',  255325,  255442,  36.90, '9.0E-04', 1, 94, '0', 'full', 1),
('RF00504', 'D84432.1',    169999,  170100,  38.00, '4.0E-04', 1, 94, '0', 'full', 1),
('RF00504', 'AE017355.1',  2242862, 2242962, 36.20, '1.2E-03', 1, 94, '0', 'full', 1),
('RF00504', 'AL591978.1',  212840,  212931,  37.50, '7.0E-04', 1, 94, '0', 'full', 1),
('RF00504', 'AL596168.1',  161626,  161717,  37.10, '8.5E-04', 1, 94, '0', 'full', 1),
('RF00504', 'AJ312125.1',  315,     453,     35.80, '1.5E-03', 1, 94, '0', 'full', 1),
('RF00504', 'AL766849.1',  65640,   65772,   37.30, '7.5E-04', 1, 94, '0', 'full', 1),
('RF00504', 'CP000919.1',  381215,  381303,  36.70, '1.0E-03', 1, 94, '0', 'full', 1),
('RF00504', 'CP000262.1',  1070832, 1070913, 35.50, '1.8E-03', 1, 94, '0', 'full', 1),
('RF00504', 'BX897699.1',  1435876, 1435970, 37.60, '6.5E-04', 1, 94, '0', 'full', 1),
('RF00504', 'BX572605.1',  160757,  160849,  38.20, '3.5E-04', 1, 94, '0', 'full', 1),
('RF00504', 'AE014292.2',  713218,  713320,  36.00, '1.3E-03', 1, 94, '0', 'full', 1),
('RF00504', 'BX640439.1',  206443,  206535,  37.40, '7.2E-04', 1, 94, '0', 'full', 1),
('RF00504', 'BX640445.1',  160126,  160210,  36.60, '1.1E-03', 1, 94, '0', 'full', 1),
('RF00504', 'CR378670.1',  15794,   15904,   37.70, '6.2E-04', 1, 94, '0', 'full', 1),
('RF00504', 'AE008923.1',  1392356, 1392465, 36.30, '1.15E-03', 1, 94, '0', 'full', 1);

-- ── Seed Data: RF00504 seed_region (for bio_rfam_htmlalignment.t) ──
-- Positions from RF00504 Stockholm AC tags. Only one entry per unique
-- rfamseq_acc (PK is rfam_acc + rfamseq_acc). Uses first occurrence
-- from taxonomy_labels.stockholm.

INSERT INTO seed_region (rfam_acc, rfamseq_acc, seq_start, seq_end) VALUES
('RF00504', 'BX842577.1',  344457,  344587),
('RF00504', 'AE000516.2',  79185,   79275),
('RF00504', 'BX842572.1',  79095,   79202),
('RF00504', 'AJ301559.2',  6878,    7012),
('RF00504', 'AE016822.1',  1714420, 1714518),
('RF00504', 'AL939123.1',  278052,  278145),
('RF00504', 'AL939108.1',  255325,  255442),
('RF00504', 'D84432.1',    169999,  170100),
('RF00504', 'AE017355.1',  2242862, 2242962),
('RF00504', 'AL591978.1',  212840,  212931),
('RF00504', 'AL596168.1',  161626,  161717),
('RF00504', 'AJ312125.1',  315,     453),
('RF00504', 'AE008691.1',  313055,  313165),
('RF00504', 'AL766849.1',  65640,   65772),
('RF00504', 'CP000919.1',  381215,  381303),
('RF00504', 'CP000262.1',  1070832, 1070913),
('RF00504', 'BX897699.1',  1435876, 1435970),
('RF00504', 'BX572605.1',  160757,  160849),
('RF00504', 'AE014292.2',  713218,  713320),
('RF00504', 'AL591688.1',  1674906, 1674990),
('RF00504', 'BX640439.1',  206443,  206535),
('RF00504', 'BX640445.1',  160126,  160210),
('RF00504', 'CR522870.1',  1448704, 1448793),
('RF00504', 'BX950851.1',  2645034, 2645129),
('RF00504', 'AE004439.1',  116056,  116172),
('RF00504', 'CR543861.1',  1989965, 1990073),
('RF00504', 'CR378670.1',  15794,   15904),
('RF00504', 'AE008922.1',  1299896, 1299977),
('RF00504', 'AE008923.1',  1392356, 1392465);
