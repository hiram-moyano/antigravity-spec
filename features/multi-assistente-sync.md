---
name: multi-assistente-sync
description: Feature spec ratificada como P-101 a P-106 na constituicao v1.3.0. Governanca de escrita compartilhada Claude Code + Antigravity.
source_of_truth: true
canonical_path: Antigravity Root/.spec/features/multi-assistente-sync.md
mirrors: []
last_verified: 2026-09-17
verified_by: Claude Code (Opus 4.7)
status: ratificada
ratified_in: .spec/constituicao.md#p-101-a-p-106
---
# Feature Spec â€” GovernanÃ§a Multi-Assistente (Antigravity â†” Claude Code)

**Status:** Draft (proposto por Claude Code em 2026-09-15, aguardando ratificaÃ§Ã£o do Hiram + Oscar/Nexus)
**Fonte Ãºnica da verdade:** este arquivo
**Escopo:** todo artefato compartilhado entre Antigravity e Claude Code (skills, rules, workflows, specs, `/upcode`, comandos, agentes, grafos).

---

## Problema real (observado hoje, 2026-09-15)

SequÃªncia que aconteceu no `meus-projetos-01` em ~1 hora:

1. **15:50** â€” Claude Code corrigiu `Antigravity Root/.agents/skills/upcode/SKILL.md` (comando `python -m graphify --update` â†’ `graphify update <path>`).
2. **16:00** â€” Antigravity, rodando na mesma mÃ¡quina, regenerou o mesmo SKILL.md a partir de um cache/template interno e **restaurou o comando errado** (com uma variaÃ§Ã£o: `--update --code-only`). Nenhum log, nenhum aviso, nenhum merge conflict.
3. **16:53** â€” Auto-sync horÃ¡rio commitou a regressÃ£o silenciosamente.

Nada disso aparece como conflito no git porque as escritas foram sequenciais. **A parceria multi-assistente hoje Ã© last-write-wins puro.**

Hiram, na conversa de introduÃ§Ã£o deste spec: *"eu acreditei que trabalhando com as specs bem definidas e agora trazendo esse sistema de grafos eu estaria atacando exatamente esse problema de cada um fazer uma coisa diferente"*. Essa crenÃ§a estÃ¡ **certa em princÃ­pio** â€” mas exige as regras deste documento pra virar prÃ¡tica.

---

## PrincÃ­pio central

> **Todo artefato editÃ¡vel por mais de um assistente tem uma Fonte Ãšnica da Verdade (SSOT) declarada em frontmatter. Assistentes leem antes de escrever, e nunca escrevem em cÃ³pias-espelho.**

CorolÃ¡rio: o grafo Graphify Ã© a memÃ³ria compartilhada dessa federaÃ§Ã£o. Antes de sobrescrever qualquer SSOT, o assistente **consulta** o grafo pra saber se a mudanÃ§a Ã© evoluÃ§Ã£o ou regressÃ£o.

---

## Regras propostas para a ConstituiÃ§Ã£o

NumeraÃ§Ã£o sugerida (a definir pelo Nexus quando ratificar).

### P-1XX-A [DEVE] Todo artefato compartilhado declara papel no frontmatter

Todo `.md` que possa ser editado por Antigravity **e** Claude Code (skills, rules, workflows, feature specs) tem frontmatter YAML com exatamente uma das duas chaves:

```yaml
source_of_truth: true
canonical_path: <caminho relativo Ã  AI Roots>
mirrors:
  - <caminho do espelho 1>
  - <caminho do espelho 2>
last_verified: YYYY-MM-DD
verified_by: <nome do assistente ou humano>
```

OU

```yaml
mirror_of: <caminho do SSOT>
# demais campos podem existir mas source_of_truth NÃƒO pode existir
```

- **verificaÃ§Ã£o(gate):** script `.spec/verification/verify-ssot-frontmatter.ps1` (a criar) que falha se algum `.agents/skills/**/SKILL.md`, `.claude/skills/**/SKILL.md` ou `.spec/features/*.md` estiver sem esse frontmatter.

### P-1XX-B [DEVE] Nenhum assistente escreve em arquivo com `mirror_of:`

Editou o SSOT? Roda o script de propagaÃ§Ã£o. Editou o mirror? Erro â€” reverter e reeditar o SSOT.

- **verificaÃ§Ã£o(gate):** pre-commit hook que faz `git diff --cached` e falha se algum arquivo modificado tiver `mirror_of:` no frontmatter.

### P-1XX-C [DEVE] Antes de regenerar arquivo canÃ´nico, consultar grafo

Nenhum assistente sobrescreve arquivo com `source_of_truth: true` a partir de cache/template sem antes:
1. Rodar `graphify explain "<node relevante>"` OU `graphify query "<pergunta sobre o arquivo>"` pra saber o estado atual conhecido.
2. Comparar com a versÃ£o que pretende escrever.
3. Se a nova versÃ£o remove sÃ­mbolo/comando/regra que o grafo conhece, Ã© **regressÃ£o** â€” abortar e pedir confirmaÃ§Ã£o humana.

- **verificaÃ§Ã£o(proibido):** ausÃªncia de log `.upcode/pre-write-checks.jsonl` da checagem antes de escrever SSOT.

### P-1XX-D [DEVE] Grafos versionados usam merge driver do Graphify

`.gitattributes` de cada projeto registra:

```
graphify-out/graph.json merge=graphify-union
```

Instalar via `graphify hook install` uma vez por clone. Isso substitui last-write-wins por union-merge determinÃ­stico.

- **verificaÃ§Ã£o(gate):** `git check-attr merge graphify-out/graph.json` retorna `graphify-union`.

### P-1XX-E [PODE] SessÃ£o declara escopo antes de tocar SSOT

Cada sessÃ£o de assistente escreve em `.upcode/session.jsonl` uma linha ao comeÃ§ar:

```json
{"ts":"2026-09-15T15:50:00Z","agent":"claude-code","session":"<id>","scope":["skills/upcode","auto-sync-projetos.bat"]}
```

Ao ver o log, o prÃ³ximo assistente sabe que "alguÃ©m estÃ¡ mexendo em `skills/upcode` agora â€” ou espero, ou coordeno". NÃ£o Ã© lock rÃ­gido, Ã© sinal.

### P-1XX-F [DEVE] Skill compartilhada carrega header "nÃ£o regenerar"

Todo SSOT que Ã© um SKILL.md tem, logo abaixo do frontmatter, um bloco de comentÃ¡rio HTML com:
1. Marcador visual (linha `â•â•â•`).
2. Motivo pelo qual nÃ£o pode ser regenerado automaticamente.
3. RegressÃµes conhecidas que **nÃ£o** podem reaparecer.

Modelo funcional em: `Antigravity Root/.agents/skills/upcode/SKILL.md`.

---

## Mecanismos operacionais (implementaÃ§Ã£o da governanÃ§a)

### 1. Script de propagaÃ§Ã£o (`.upcode/propagate-skill.ps1`)

Uma vez que o SSOT muda, roda `propagate-skill.ps1 <caminho-do-ssot>`. Ele:
- LÃª `mirrors:` do frontmatter.
- Copia body para cada mirror substituindo `source_of_truth: true` por `mirror_of: <ssot>` no frontmatter.
- Adiciona comentÃ¡rio "generated from <ssot> @ <hash-do-ssot>".
- Falha se algum mirror foi editado Ã  mÃ£o desde a Ãºltima propagaÃ§Ã£o (tem hash divergente).

### 2. Pre-commit hook (`.git/hooks/pre-commit`)

Verifica todas as P-1XX antes de deixar commitar. Roda `verify-ssot-frontmatter.ps1`, checa `mirror_of` nÃ£o modificado, checa header "nÃ£o regenerar" presente.

### 3. Pipeline `/upcode` incorpora as checagens

Passo novo no workflow do `/upcode` (a acrescentar depois de ratificado):
- **1.5** â€” Rodar propagate-skill em todo SSOT modificado desde o Ãºltimo auto-sync.
- **2.5** â€” Rodar `graphify diagnose multigraph` no grafo global; abortar se `same_endpoint_group_count > 0` (indica que algum merge foi mal).

### 4. Grafo como Ã¡rbitro semÃ¢ntico

Adicionar ao `.upcode` uma verificaÃ§Ã£o: se a mudanÃ§a que Nexus/Vector/Claude vai fazer remove um nÃ³ com `degree > 5` ou desconecta uma comunidade, tratar como **breaking change** e exigir aprovaÃ§Ã£o humana explÃ­cita.

---

## DecisÃµes abertas (para Hiram)

1. **Qual Ã© o SSOT canÃ´nico para skills que existem em Antigravity + Claude?** SugestÃ£o: Antigravity, porque o conceito Oscar/Nexus/Vector foi desenhado lÃ¡. Alternativa: mover pra `Arquivos gerais IA/skills-canonicas/` e ambos ambientes viram mirrors.

2. **AceitÃ¡vel que o pre-commit hook rejeite commit atÃ© o mirror estar sincronizado?** Fluxo mais rÃ­gido, mas garante nunca sair de sync. Alternativa mais leve: warning ao invÃ©s de erro.

3. **`.upcode/` deve ser gitignored ou committed?** Committado permite auditoria histÃ³rica ("quem mexeu em quÃª"); gitignored economiza ruÃ­do no repo.

4. **NumeraÃ§Ã£o P-1XX** ou outra sÃ©rie? A constituiÃ§Ã£o atual estÃ¡ em P-0XX; sugiro P-1XX pra separar "governanÃ§a de agentes" de "regras de cÃ³digo".

---

## VerificaÃ§Ã£o de ratificaÃ§Ã£o

Este spec vira norma quando:
- [ ] Hiram aprova (comentÃ¡rio em issue ou commit).
- [ ] Nexus roda `.spec/verification/verify-ratification.ps1 multi-assistente-sync` (a criar).
- [ ] As 6 P-1XX sÃ£o copiadas pra `.spec/constituicao.md` com numeraÃ§Ã£o final.
- [ ] `Antigravity Root/.agents/skills/upcode/SKILL.md` (jÃ¡ feito) e ambos os mirrors passam `verify-ssot-frontmatter.ps1`.
- [ ] Merge driver `graphify-union` instalado no repo `meus-projetos-01`.
