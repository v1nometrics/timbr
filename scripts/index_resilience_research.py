#!/usr/bin/env python3
"""Index the research snapshot without confusing keyword triage with validated coverage."""
import csv, json, pathlib, re
root=pathlib.Path(__file__).resolve().parents[1]
p=root/'docs/00-pesquisa/resiliencia-2026-11-23'
rules={
 'ciclo-de-vida':r'sleep|wake|restart|coreaudiod|resume|lock screen',
 'seguranca-volume':r'mute|volume|loud|blast|gain|attenuat',
 'audio-integridade':r'distort|crack|stutter|sample.rate|latency|drift|channel|silence|no sound|audio.*stop',
 'recursos':r'cpu|memory|leak|battery|energy|power|freeze|hang|crash',
 'telas-interacao':r'display|monitor|screen|notch|hover|focus|space|keyboard|key|hud',
 'permissoes-distribuicao':r'permission|accessibility|tcc|sign|install|update|launch|sandbox',
 'persistencia':r'persist|save|reset|preset|import|export|setting',
 'midia':r'spotify|music|media|artwork|playing|lyrics',
 'dispositivos':r'bluetooth|airpod|usb|dac|hdmi|airplay|headphone|microphone|input|output',
}
rows=[]
for f in sorted(p.glob('*.json')):
 if f.name=='coleta.json':continue
 for x in json.loads(f.read_text()):
  # Title only: all bodies remain available in the source JSON for actual review.
  categories=[k for k,v in rules.items() if re.search(v,x['title'],re.I)]
  rows.append(dict(repo=f.stem.replace('_','/',1),number=x['number'],title=x['title'],state=x['state'],url=x['html_url'],triagem_por_titulo=';'.join(categories) or 'sem-classificacao',revisao='pendente',teste_timbr='nao-vinculado'))
with (p/'inventario.csv').open('w') as out:
 w=csv.DictWriter(out,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
manifest=json.loads((p/'coleta.json').read_text())
text=['# Snapshot de rastreadores públicos','',f'{len(rows)} issues de {len(manifest["repositories"])} repositórios. Coleta: {manifest["collected_at"]}.','',
'Paginação integral dos endpoints consultados, abertas e fechadas; PRs excluídos. O corpo está no JSON. Comentários, anexos, discussions e PRs ainda não foram coletados. Não equivale a todas as falhas existentes nem à revisão humana de todos os registros.','',
'`inventario.csv`: uma linha por issue, URL e estado upstream. Categorias são sugestões por palavras no título, incluindo feature requests; não são diagnóstico. Todas começam pendentes e sem teste vinculado. Não use contagem de issues como contagem de bugs.','',
'Atualização: a coleta pode ser refeita via GitHub REST `/repos/{owner}/{repo}/issues?state=all&per_page=100`, seguindo todos os links de paginação e excluindo `pull_request`. `scripts/index_resilience_research.py` regenera somente o índice.','', '| Repositório | Issues coletadas |','|---|---:|']
for r in manifest['repositories']:text.append(f'| {r["repo"]} | {r.get("count", "ERRO")} |')
(p/'README.md').write_text('\n'.join(text)+'\n')
print(len(rows))
