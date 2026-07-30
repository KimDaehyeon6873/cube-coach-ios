#!/usr/bin/env python3

"""Generate the pinned, MIT-attributed 3×3 learning catalog.

Usage:
  Tools/generate_full_algorithm_catalog.py \
    --cubingapp /path/to/cubingapp \
    --cubedex /path/to/cubedex
"""

import argparse
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--cubingapp", type=Path, required=True)
parser.add_argument("--cubedex", type=Path, required=True)
args = parser.parse_args()

cubing = args.cubingapp / "tanstack/src/routes/algorithms/algs"
cubedex = json.loads((args.cubedex / "src/data/defaultAlgs.json").read_text())

TOKEN = re.compile(r"^([RLUDFBMESxyz]|[rludfb])(w)?(2|'|3)?('?)*$")

def normalize_token(token):
    token = token.strip().replace('’', "'").replace('′', "'")
    if not token: return None
    # Source grouping punctuation is non-semantic.
    token = token.strip('()[]{}')
    if not token: return None
    if '+' in token or '-' in token or '/' in token: return None
    m = re.fullmatch(r"([RLUDFBMESxyzrludfb])(w)?(2|3)?(')?", token)
    if not m: return None
    sym, wide, amount, prime = m.groups()
    if sym in 'rludfb':
        sym = sym.upper(); wide = 'w'
    if sym in 'MESxyz' and wide: return None
    if amount == '3':
        amount = None
        prime = "'" if not prime else None
    if amount == '2':
        prime = None
    return sym + (wide or '') + (amount or '') + (prime or '')

def normalize_alg(raw):
    raw = raw.replace('(', ' ').replace(')', ' ')
    result=[]
    for piece in raw.split():
        token=normalize_token(piece)
        if token is None: return None
        result.append(token)
    return ' '.join(result) if result else None

def quarter(token):
    if token.endswith('2'): return 2
    if token.endswith("'"): return 3
    return 1

def rotation_contribution(token):
    t=token
    q=quarter(t)
    base=t.rstrip("2'")
    if base in 'xyz': return (base,q)
    wide_map={'Rw':('x',1),'Lw':('x',3),'Uw':('y',1),'Dw':('y',3),'Fw':('z',1),'Bw':('z',3)}
    slice_map={'M':('x',3),'E':('y',3),'S':('z',1)}
    if base in wide_map:
        axis, direction=wide_map[base]; return axis,(direction*q)%4
    if base in slice_map:
        axis,direction=slice_map[base]; return axis,(direction*q)%4
    return None

def rot(v, axis):
    x,y,z=v
    if axis=='x': return (x,-z,y)
    if axis=='y': return (z,y,-x)
    return (-y,x,z)

def identity_orientation(alg):
    basis=[(1,0,0),(0,1,0),(0,0,1)]
    for token in alg.split():
        contribution=rotation_contribution(token)
        if contribution:
            axis,q=contribution
            for _ in range(q): basis=[rot(v,axis) for v in basis]
    return basis==[(1,0,0),(0,1,0),(0,0,1)]

def compatible(raw):
    alg=normalize_alg(raw)
    return alg if alg and identity_orientation(alg) else None

def swift(s):
    return '"' + s.replace('\\','\\\\').replace('"','\\"') + '"'

def slug(s):
    return re.sub(r'[^a-z0-9]+','-',s.lower()).strip('-')

def cases_from_cubing(set_name, prefix, family_ko):
    data=json.loads((cubing/f'{set_name}.json').read_text())
    rows=[]
    for key,value in data['cases'].items():
        variants=[]
        for raw in value['algs'].keys():
            alg=compatible(raw)
            if alg and alg not in variants: variants.append(alg)
        if not variants:
            raise RuntimeError(f'No compatible algorithm for {set_name} {key}')
        rows.append(dict(id=f'{prefix}-{slug(key)}',name=key,subset=value.get('subset',''),family=family_ko,variants=variants[:6]))
    return rows

def cases_from_cubedex(set_name,prefix,family_ko):
    rows=[]
    for group in cubedex[set_name]:
        subset=group['subset']
        for item in group['algorithms']:
            alg=compatible(item['algorithm'])
            if not alg: raise RuntimeError(f'No compatible algorithm for {set_name} {item}')
            rows.append(dict(id=f'{prefix}-{slug(item["name"])}',name=item['name'],subset=subset,family=family_ko,variants=[alg]))
    return rows

sets={
 'two_oll':cases_from_cubing('2-Look-OLL','2look-oll','2-Look OLL'),
 'two_pll':cases_from_cubing('2-Look-PLL','2look-pll','2-Look PLL'),
 'f2l':cases_from_cubing('F2L','full-f2l','Full F2L'),
 'oll':cases_from_cubing('OLL','full-oll','Full OLL'),
 'pll':cases_from_cubing('PLL','full-pll','Full PLL'),
 'coll':cases_from_cubing('COLL','coll','COLL'),
 'cmll':cases_from_cubedex('CMLL','cmll','Roux CMLL'),
}

def emit_rows(rows, indent='                '):
    out=[]
    for row in rows:
        hint=f"{row['subset']} · 시작 전개도의 윗면과 옆면 패턴을 확인하세요." if row['subset'] else "시작 전개도의 윗면과 옆면 패턴을 확인하세요."
        alternatives=', '.join(swift(x) for x in row['variants'][1:])
        out.append(indent + 'generatedSample(')
        out.append(indent + f'    id: {swift(row["id"])},')
        out.append(indent + f'    name: {swift(row["name"])},')
        out.append(indent + f'    notation: {swift(row["variants"][0])},')
        out.append(indent + f'    recognitionHint: {swift(hint)},')
        out.append(indent + f'    alternativeNotations: [{alternatives}]')
        out.append(indent + '),')
    return '\n'.join(out)

content=f'''// Generated from MIT-licensed upstream algorithm catalogs. Do not edit cases by hand.
// cubingapp commit 613a49885dc618023368e5f0c2a25024b8c7e9a5
// cubedex commit e5849e2c0e58df681a707a7b7c8fc30a43405d3b

import Foundation

extension CurriculumCatalog {{
    static let openAlgorithmSource = LearningSource(
        title: "3×3 algorithm catalog",
        publisher: "cubingapp contributors",
        url: "https://github.com/spencerchubb/cubingapp/tree/613a49885dc618023368e5f0c2a25024b8c7e9a5/tanstack/src/routes/algorithms/algs",
        note: "F2L 41, OLL 57, PLL 21, 2-Look OLL/PLL, COLL 후보를 앱 엔진으로 재검증",
        licenseName: "MIT License",
        licenseURL: "https://github.com/spencerchubb/cubingapp/blob/613a49885dc618023368e5f0c2a25024b8c7e9a5/LICENSE"
    )

    static let openCMLLSource = LearningSource(
        title: "CMLL algorithm catalog",
        publisher: "CubeDex contributors",
        url: "https://github.com/poliva/cubedex/blob/e5849e2c0e58df681a707a7b7c8fc30a43405d3b/src/data/defaultAlgs.json",
        note: "Roux CMLL 42개 공식을 앱 엔진으로 재검증",
        licenseName: "MIT License",
        licenseURL: "https://github.com/poliva/cubedex/blob/e5849e2c0e58df681a707a7b7c8fc30a43405d3b/LICENSE"
    )

    static func generatedSample(
        id: String,
        name: String,
        notation: String,
        recognitionHint: String,
        alternativeNotations: [String]
    ) -> AlgorithmSample {{
        do {{
            let solution = try WCAParser.parse(notation)
            let recommendedSetup = try CubeState.solved.executing(solution.inverse)
            guard recommendedSetup.orientation == .identity else {{
                preconditionFailure("Generated algorithm changes the holding orientation: \\(id)")
            }}
            let normalizedAlternatives: [String] = try alternativeNotations.compactMap {{ notation in
                let alternative = try WCAParser.parse(notation)
                let alternativeSetup = try CubeState.solved.executing(alternative.inverse)
                guard alternativeSetup.orientation == .identity,
                      alternativeSetup.cube == recommendedSetup.cube else {{
                    return nil as String?
                }}
                return alternative.normalized
            }}
            let boundaries = Array(stride(from: 0, to: solution.moves.count, by: 4)) + [solution.moves.count]
            return executableSample(
                id: id,
                name: name,
                notation: solution.normalized,
                recognitionHint: recognitionHint,
                setup: solution.inverse.normalized,
                chunks: boundaries,
                alternativeNotations: normalizedAlternatives
            )
        }} catch {{
            preconditionFailure("Invalid generated algorithm \\(id): \\(error)")
        }}
    }}

    static func makeTwoLookCFOP() -> Curriculum {{
        Curriculum(track: .twoLookCFOP, title: "2-Look CFOP", lessons: [
            CurriculumLesson(
                id: "two-look-oll-complete",
                title: "2-Look OLL 전체",
                objective: "엣지와 코너를 두 단계로 나눠 윗면 방향을 맞춰요.",
                algorithms: [
{emit_rows(sets['two_oll'])}
                ],
                sources: [openAlgorithmSource, notationSource]
            ),
            CurriculumLesson(
                id: "two-look-pll-complete",
                title: "2-Look PLL 전체",
                objective: "코너와 엣지를 두 단계로 나눠 마지막 층 위치를 맞춰요.",
                algorithms: [
{emit_rows(sets['two_pll'])}
                ],
                sources: [openAlgorithmSource, notationSource]
            ),
        ])
    }}

    public static let fullCFOP = Curriculum(track: .fullCFOP, title: "Full CFOP", lessons: [
        CurriculumLesson(
            id: "full-f2l",
            title: "F2L 41",
            objective: "코너와 엣지의 관계를 보고 한 슬롯씩 효율적으로 해결해요.",
            algorithms: [
{emit_rows(sets['f2l'])}
            ],
            sources: [openAlgorithmSource, notationSource]
        ),
        CurriculumLesson(
            id: "full-oll",
            title: "OLL 57",
            objective: "마지막 층 57개 방향 패턴을 한 번에 해결해요.",
            algorithms: [
{emit_rows(sets['oll'])}
            ],
            sources: [openAlgorithmSource, notationSource]
        ),
        CurriculumLesson(
            id: "full-pll",
            title: "PLL 21",
            objective: "방향이 맞은 마지막 층의 21개 순열을 한 번에 해결해요.",
            algorithms: [
{emit_rows(sets['pll'])}
            ],
            sources: [openAlgorithmSource, notationSource]
        ),
    ])

    public static let advancedLastLayer = Curriculum(
        track: .advancedLastLayer,
        title: "고급 마지막 층",
        lessons: [
            CurriculumLesson(
                id: "coll-complete",
                title: "COLL 40",
                objective: "윗면 엣지가 맞은 상태에서 코너 방향과 순열을 함께 해결해요.",
                algorithms: [
{emit_rows(sets['coll'])}
                ],
                sources: [openAlgorithmSource, notationSource]
            ),
        ]
    )

    public static let rouxCMLL = Curriculum(
        track: .rouxCMLL,
        title: "Roux 스피드 해법",
        lessons: [
            CurriculumLesson(
                id: "roux-cmll-complete",
                title: "CMLL 42",
                objective: "Roux의 두 블록을 유지하며 마지막 층 코너를 해결해요.",
                algorithms: [
{emit_rows(sets['cmll'])}
                ],
                sources: [openCMLLSource, notationSource]
            ),
        ]
    )
}}
'''
output = Path("Sources/CubeCoachCore/FullAlgorithmCatalog.swift")
output.write_text(content)
print({k:len(v) for k,v in sets.items()})
print('total generated',sum(map(len,sets.values())))
