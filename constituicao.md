# Constituição — v1.3.1

> **AVISO DE FONTE ÚNICA DA VERDADE:**  
> A constituição dos Agentes Maestros foi consolidada e é mantida oficialmente em [`.agents/PROTOCOLO_AGENTES_MAESTROS.md`](file:///d:/ARQUIVO%20CENTRAL/TUDO%20BEM%20PARATY/AI%20Roots/.agents/PROTOCOLO_AGENTES_MAESTROS.md).
>
> **Histórico de versões:**
> - v1.3.1 (2026-09-18): só correção de caminhos após a reestruturação de 17/09 (`MEUS_AGENTES` → `.agents/`); nenhuma regra alterada.
> - v1.3.0 (2026-09-17): ratificação das P-101 a P-106 (governança multi-assistente). Origem: `.spec/features/multi-assistente-sync.md`.
> - v1.2.0: baseline com P-001 e P-002.

---

# Série P-0XX — Fundamentos de Qualidade de Código

## P-001 [DEVE] Todo requisito tem prova executável
Nenhuma feature é declarada pronta sem a suíte de testes (ex: `node test/agents.test.js`) e auditoria limpa (exit 0).
- verificação(gate): intrínseca ao audit

## P-002 [DEVE] Segredos e Chaves nunca em código
Chaves de API (ex: `GEMINI_API_KEY`, tokens GitHub) vêm de variáveis de ambiente (`CONFIG/.env`), jamais gravadas no código ou commitadas.
- verificação(proibido): `(api[_-]?key|senha|password)\s*[:=]\s*['"][^'"]{8,}` em `src/**/*.js`

---

# Série P-1XX — Governança Multi-Assistente (Claude Code ↔ Antigravity)

> Ratificado em 2026-09-17. Origem: DRAFT em `.spec/features/multi-assistente-sync.md`, criado após incidente de `last-write-wins` em `skills/upcode` (2026-09-15).

## P-101 [DEVE] Todo artefato compartilhado declara papel no frontmatter
Todo `.md` que possa ser editado por Antigravity **e** Claude Code (skills em `.agents/skills/`, rules em `.agents/rules/`, workflows em `.agents/workflows/`, feature specs em `.spec/features/`) tem frontmatter YAML com exatamente uma das duas chaves:

```yaml
source_of_truth: true
canonical_path: <caminho relativo à AI Roots>
mirrors:
  - <caminho do espelho 1>
last_verified: YYYY-MM-DD
verified_by: <nome do assistente ou humano>
```

OU

```yaml
mirror_of: <caminho do SSOT>
last_verified: YYYY-MM-DD
verified_by: <nome do assistente ou humano>
```

- verificação(gate): `Antigravity Root/.spec/verification/verify-ssot-frontmatter.ps1` falha se algum arquivo escopado estiver sem esse frontmatter.

## P-102 [DEVE] Nenhum assistente escreve em arquivo com `mirror_of:`
Editou o SSOT? Roda `.spec/verification/propagate-skill.ps1 <caminho-do-ssot>`. Editou o mirror? Erro — reverter e reeditar o SSOT.

- verificação(gate): pre-commit hook faz `git diff --cached` e falha se algum arquivo modificado tiver `mirror_of:` no frontmatter.

## P-103 [DEVE] Antes de regenerar arquivo canônico, consultar grafo
Nenhum assistente sobrescreve arquivo com `source_of_truth: true` a partir de cache/template sem antes:
1. Rodar `graphify explain "<node relevante>"` OU `graphify query "<pergunta sobre o arquivo>"` pra saber o estado atual conhecido.
2. Comparar com a versão que pretende escrever.
3. Se a nova versão remove símbolo/comando/regra que o grafo conhece, é **regressão** — abortar e pedir confirmação humana.

- verificação(proibido): ausência de log em `.upcode/pre-write-checks.jsonl` da checagem antes de escrever SSOT (aplica-se apenas quando o script `pre-write-check.ps1` estiver instalado; até lá, é norma de conduta).

## P-104 [DEVE] Grafos versionados usam merge driver do Graphify
`.gitattributes` de cada projeto com grafo versionado registra:

```
graphify-out/graph.json merge=graphify
```

Instalar via `graphify hook install` uma vez por clone — isso registra o driver `merge.graphify.driver` no `.git/config` local e instala hooks `post-commit`/`post-checkout`. Substitui last-write-wins por union-merge determinístico.

- verificação(gate): `git check-attr merge graphify-out/graph.json` retorna `graphify` em todo repo que contenha `graphify-out/`.

> **Nota histórica:** o DRAFT `.spec/features/multi-assistente-sync.md` chamava o driver de `graphify-union` (nome descritivo do comportamento). A CLI real do graphify 0.9.62 usa `graphify` como identificador. A regra aqui reflete a implementação; o comportamento é o mesmo (union merge).

## P-105 [PODE] Sessão declara escopo antes de tocar SSOT
Cada sessão de assistente escreve em `.upcode/session.jsonl` uma linha ao começar:

```json
{"ts":"2026-09-17T17:30:00Z","agent":"claude-code","session":"<id>","scope":["skills/upcode","auto-sync-projetos.bat"]}
```

Ao ver o log, o próximo assistente sabe que "alguém está mexendo em X agora — ou espero, ou coordeno". Não é lock rígido, é sinal.

Helper disponível: `.upcode/declare-session.ps1 -Agent claude-code -Scope skills/upcode,rules/graphify.md`.

## P-106 [DEVE] Skill compartilhada carrega header "não regenerar"
Todo SSOT que é um SKILL.md tem, logo abaixo do frontmatter, um bloco de comentário HTML com:
1. Marcador visual (linha `═══`).
2. Motivo pelo qual não pode ser regenerado automaticamente.
3. Regressões conhecidas que **não** podem reaparecer.

Modelo funcional em: `.agents/skills/upcode/SKILL.md`.
