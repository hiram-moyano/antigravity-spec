---
name: multi-assistente-sync
description: Feature spec ratificada como P-101 a P-106 na constituicao v1.3.0. Governanca de escrita compartilhada Claude Code + Antigravity + ZCode.
source_of_truth: true
canonical_path: Antigravity Root/.spec/features/multi-assistente-sync.md
mirrors: []
last_verified: 2026-09-21
verified_by: Antigravity
status: ratificada
ratified_in: .spec/constituicao.md#p-101-a-p-106
---
# Feature Spec — Governança Multi-Assistente (Tríade: Antigravity ↔ Claude Code ↔ ZCode)

**Status:** Ratificada (atualizada em 2026-09-21 com inclusão do ZCode)
**Fonte única da verdade:** este arquivo
**Escopo:** todo artefato compartilhado entre Antigravity, Claude Code e ZCode (skills, rules, workflows, specs, `/upcode`, comandos, agentes, grafos).

---

## Problema real (observado hoje, 2026-09-15)

Sequência que aconteceu no `meus-projetos-01` em ~1 hora:

1. **15:50** — Claude Code corrigiu `Antigravity Root/.agents/skills/upcode/SKILL.md` (comando `python -m graphify --update` → `graphify update <path>`).
2. **16:00** — Antigravity, rodando na mesma máquina, regenerou o mesmo SKILL.md a partir de um cache/template interno e **restaurou o comando errado** (com uma variação: `--update --code-only`). Nenhum log, nenhum aviso, nenhum merge conflict.
3. **16:53** — Auto-sync horário commitou a regressão silenciosamente.

Nada disso aparece como conflito no git porque as escritas foram sequenciais. **A parceria multi-assistente hoje é last-write-wins puro.**

Hiram, na conversa de introdução deste spec: *"eu acreditei que trabalhando com as specs bem definidas e agora trazendo esse sistema de grafos eu estaria atacando exatamente esse problema de cada um fazer uma coisa diferente"*. Essa crença está **certa em princípio** — mas exige as regras deste documento pra virar prática.

---

## Princípio central

> **Todo artefato editável por mais de um assistente tem uma Fonte Única da Verdade (SSOT) declarada em frontmatter. Assistentes leem antes de escrever, e nunca escrevem em cópias-espelho.**

Corolário: o grafo Graphify é a memória compartilhada dessa federação. Antes de sobrescrever qualquer SSOT, o assistente **consulta** o grafo pra saber se a mudança é evolução ou regressão.

---

## Regras propostas para a Constituição

Numeração sugerida (a definir pelo Nexus quando ratificar).

### P-1XX-A [DEVE] Todo artefato compartilhado declara papel no frontmatter

Todo `.md` que possa ser editado por Antigravity **e** Claude Code (skills, rules, workflows, feature specs) tem frontmatter YAML com exatamente uma das duas chaves:

```yaml
source_of_truth: true
canonical_path: <caminho relativo à AI Roots>
mirrors:
  - <caminho do espelho 1>
  - <caminho do espelho 2>
last_verified: YYYY-MM-DD
verified_by: <nome do assistente ou humano>
```

OU

```yaml
mirror_of: <caminho do SSOT>
# demais campos podem existir mas source_of_truth NÃO pode existir
```

- **verificação(gate):** script `.spec/verification/verify-ssot-frontmatter.ps1` (a criar) que falha se algum `.agents/skills/**/SKILL.md`, `.claude/skills/**/SKILL.md` ou `.spec/features/*.md` estiver sem esse frontmatter.

### P-1XX-B [DEVE] Nenhum assistente escreve em arquivo com `mirror_of:`

Editou o SSOT? Roda o script de propagação. Editou o mirror? Erro — reverter e reeditar o SSOT.

- **verificação(gate):** pre-commit hook que faz `git diff --cached` e falha se algum arquivo modificado tiver `mirror_of:` no frontmatter.

### P-1XX-C [DEVE] Antes de regenerar arquivo canônico, consultar grafo

Nenhum assistente sobrescreve arquivo com `source_of_truth: true` a partir de cache/template sem antes:
1. Rodar `graphify explain "<node relevante>"` OU `graphify query "<pergunta sobre o arquivo>"` pra saber o estado atual conhecido.
2. Comparar com a versão que pretende escrever.
3. Se a nova versão remove símbolo/comando/regra que o grafo conhece, é **regressão** — abortar e pedir confirmação humana.

- **verificação(proibido):** ausência de log `.upcode/pre-write-checks.jsonl` da checagem antes de escrever SSOT.

### P-1XX-D [DEVE] Grafos versionados usam merge driver do Graphify

`.gitattributes` de cada projeto registra:

```
graphify-out/graph.json merge=graphify-union
```

Instalar via `graphify hook install` uma vez por clone. Isso substitui last-write-wins por union-merge determinístico.

- **verificação(gate):** `git check-attr merge graphify-out/graph.json` retorna `graphify-union`.

### P-1XX-E [PODE] Sessão declara escopo antes de tocar SSOT

Cada sessão de assistente escreve em `.upcode/session.jsonl` uma linha ao começar:

```json
{"ts":"2026-09-15T15:50:00Z","agent":"claude-code","session":"<id>","scope":["skills/upcode","auto-sync-projetos.bat"]}
```

Ao ver o log, o próximo assistente sabe que "alguém está mexendo em `skills/upcode` agora — ou espero, ou coordeno". Não é lock rígido, é sinal.

### P-1XX-F [DEVE] Skill compartilhada carrega header "não regenerar"

Todo SSOT que é um SKILL.md tem, logo abaixo do frontmatter, um bloco de comentário HTML com:
1. Marcador visual (linha `═══`).
2. Motivo pelo qual não pode ser regenerado automaticamente.
3. Regressões conhecidas que **não** podem reaparecer.

Modelo funcional em: `.agents/skills/upcode/SKILL.md` (caminho desde a reestruturação de 17/09/2026).

---

## Mecanismos operacionais (implementação da governança)

### 1. Script de propagação (`.upcode/propagate-skill.ps1`)

Uma vez que o SSOT muda, roda `propagate-skill.ps1 <caminho-do-ssot>`. Ele:
- Lê `mirrors:` do frontmatter.
- Copia body para cada mirror substituindo `source_of_truth: true` por `mirror_of: <ssot>` no frontmatter.
- Adiciona comentário "generated from <ssot> @ <hash-do-ssot>".
- Falha se algum mirror foi editado à mão desde a última propagação (tem hash divergente).

### 2. Pre-commit hook (`.git/hooks/pre-commit`)

Verifica todas as P-1XX antes de deixar commitar. Roda `verify-ssot-frontmatter.ps1`, checa `mirror_of` não modificado, checa header "não regenerar" presente.

### 3. Pipeline `/upcode` incorpora as checagens

Passo novo no workflow do `/upcode` (a acrescentar depois de ratificado):
- **1.5** — Rodar propagate-skill em todo SSOT modificado desde o último auto-sync.
- **2.5** — Rodar `graphify diagnose multigraph` no grafo global; abortar se `same_endpoint_group_count > 0` (indica que algum merge foi mal).

### 4. Grafo como árbitro semântico

Adicionar ao `.upcode` uma verificação: se a mudança que Nexus/Vector/Claude vai fazer remove um nó com `degree > 5` ou desconecta uma comunidade, tratar como **breaking change** e exigir aprovação humana explícita.

---

## Decisões abertas (para Hiram)

1. **Qual é o SSOT canônico para skills que existem em Antigravity + Claude?** Sugestão: Antigravity, porque o conceito Oscar/Nexus/Vector foi desenhado lá. Alternativa: mover pra `Arquivos gerais IA/skills-canonicas/` e ambos ambientes viram mirrors.

2. **Aceitável que o pre-commit hook rejeite commit até o mirror estar sincronizado?** Fluxo mais rígido, mas garante nunca sair de sync. Alternativa mais leve: warning ao invés de erro.

3. **`.upcode/` deve ser gitignored ou committed?** Committado permite auditoria histórica ("quem mexeu em quê"); gitignored economiza ruído no repo.

4. **Numeração P-1XX** ou outra série? A constituição atual está em P-0XX; sugiro P-1XX pra separar "governança de agentes" de "regras de código".

---

## Verificação de ratificação

Este spec vira norma quando:
- [ ] Hiram aprova (comentário em issue ou commit).
- [ ] Nexus roda `.spec/verification/verify-ratification.ps1 multi-assistente-sync` (a criar).
- [ ] As 6 P-1XX são copiadas pra `.spec/constituicao.md` com numeração final.
- [ ] `Antigravity Root/.agents/skills/upcode/SKILL.md` (já feito) e ambos os mirrors passam `verify-ssot-frontmatter.ps1`.
- [ ] Merge driver `graphify-union` instalado no repo `meus-projetos-01`.
