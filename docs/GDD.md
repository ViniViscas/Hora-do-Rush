# Hora do Rush — Documento de Design (GDD)

> Trabalho A3 · Jogo de plataforma 2D de motoqueiro entregador.
> Status: **rascunho vivo**. Itens marcados com 💡 são propostas para discutir; ❓ são dúvidas em aberto.

---

## 1. Visão geral

| | |
|---|---|
| **Gênero** | Plataforma 2D com rolagem lateral, focado em pontuação |
| **Fantasia** | Ser um motoboy na hora do rush: coletar pedidos, cortar caminho, fugir da CET e entregar dentro do prazo |
| **Engine** | Godot 4 (GDScript) |
| **Plataforma alvo** | PC (Windows) e celular (Android, tela deitada, com botões de toque) |
| **Tom visual** | *Gritty*, urbano, cansado: paleta **laranja, cinza, preto e vermelho** |

**Pilares**
1. **Correria com consequência:** velocidade dá tempo, mas os obstáculos punem quem corre demais.
2. **Perde ponto, não perde vida:** errar custa pontuação e tempo. O único game over "seco" é a **gasolina acabar**.
3. **Humor de rua:** situações reconhecíveis do dia a dia de entregador (cliente que não desce, blitz, código do pedido).

---

## 1.1 História

**Premissa:** Felipe, 28 anos, motoboy da periferia de São Paulo, mora de aluguel num quartinho e tem três contas atrasadas. Ele quer mudar de vida: virar o melhor entregador da cidade e juntar dinheiro para comprar uma casa com quintal.

**Conflito:** a moto velha vive quebrando, a CNH está vencida (por isso a CET persegue), e a cidade (lombadas, buracos, blitz, chuva, trânsito) joga contra o relógio.

**Aliada:** a **Tati**, mecânica de uma oficina de bairro, conserta a moto em troca do pagamento das entregas. O dinheiro de cada turno vai para a oficina dela (as melhorias) e para o sonho da casa.

**Capítulos:** cada bag é um capítulo. Quanto mais exigente o app, melhor ele paga, mas os prazos apertam e o estresse cresce (tema: o custo humano da pressa nos apps de entrega).

| Capítulo | Bag | Objetivo | Abertura | Final |
|---|---|---|---|---|
| 1. A casa | iFudê | Entrada da casa própria | O quartinho → a moto não liga → a oficina da Tati | A chave da casa nova |
| 2. A reforma | 99 Problemas | Reformar a casa | "Casa própria, problema próprio" (goteira, cimento) | Churrasco na laje, mas o celular não para |
| 3. A oficina | Kitreta | Salvar a oficina da Tati | "A oficina vai fechar" | Oficina reformada: "Tati & Felipe", sócios |

- O capítulo seguinte só libera ao fechar o anterior (`Config.CAPITULOS_EM_ORDEM`).
- No capítulo 3, antes da fase 4, entra a cena **"O quase"**: Felipe quase atropelado na madrugada, e a Tati manda ele parar.

**Como aparece no jogo** (`src/historia.gd`, `src/cutscene.gd`, imagens em `assets/img/cutscenes/`):

| Momento | Cena |
|---|---|
| Primeira vez que se escolhe a bag (rever: botão HISTÓRIA) | Abertura do capítulo |
| Antes de cada fase, na primeira vez | Cartão da fase, com o texto do capítulo (as cinco imagens são as mesmas nos três capítulos) |
| Ao fechar a fase 5 | Final do capítulo; a tela de fim usa a mesma imagem de fundo |
| Derrota sem gasolina / por tempo | A imagem da cena vira o fundo da tela de Game Over, com uma frase de fechamento |

- As imagens das cutscenes e o fundo da oficina foram gerados com IA (Google Gemini), declarados no README.
- O cartão da fase 5 (**Hora do Rush**) tem uma imagem por capítulo, com a bag na cor do app (`08_hora_do_rush_facil/medio/dificil.jpg`). Os outros cartões usam a mesma imagem nos três capítulos.

---

## 2. Loop principal

```
Pegar pedido no restaurante → Rodar pela cidade (obstáculos, gasolina) → Chegar no endereço
→ Esperar o cliente no portão → Digitar o código → Entregar (pontos + bônus de tempo) → próximo pedido
```

- Cada **fase** exige um **número de entregas**.
- A fase acaba com **vitória** quando todas as entregas são feitas, ou com **derrota** quando o tempo zera ou a gasolina acaba.

---

## 3. Regras centrais

### 3.1 Fase × dificuldade
- **A fase define o número de pedidos** e quais obstáculos aparecem.
- **A dificuldade (bag) define o tempo** disponível e a crueldade dos percalços.
- Cada bag tem a sua **campanha de 5 fases em sequência**: vencer uma fase libera a próxima. Fases já vencidas podem ser rejogadas (para melhorar o recorde ou juntar dinheiro).
- Cada fase tem um **mapa fixo** dentro da campanha: tentar de novo repete o mesmo mapa.

| Fase | Nome | Entregas | Tempo* | O que entra |
|---|---|---|---|---|
| 1 | Primeiro dia | 3 | ×1,2 | Poucas lombadas, buracos e cruzamentos. **Sem** blitz, chuva ou CET |
| 2 | Pegando o jeito | 4 | ×1,1 | Entra a **blitz** |
| 3 | Sexta à noite | 5 | ×1,0 | Entram **chuva** e **CET** (rua igual à do M2.5) |
| 4 | Véspera de feriado | 6 | ×0,97 | Mais lombadas, blitz parando mais gente (×1,3) |
| 5 | Hora do Rush | 7 | ×0,95 | Rua lotada (4 a 6 lombadas e buracos), chuva ×1,4, blitz ×1,5 |

\* O tempo da bag vale para 5 entregas e é proporcional ao número de entregas da fase, vezes o fator da tabela. Ex.: médio (170 s) na fase 1 = 170 × 3/5 × 1,2 ≈ 122 s.

> A rua tem 14.000 px e as folgas da seção 5.1 limitam quantos obstáculos cabem (~11 a 13). Por isso as fases 4 e 5 apertam mais pelo tempo, pela chuva e pela blitz do que pela quantidade. Tudo isso fica em `Config.FASES`.

### 3.2 Tempo e bônus por entrega antecipada
- Cada pedido tem um **prazo** (ex.: 60 s).
- Entregar antes do prazo **devolve tempo ao relógio da fase**.
- 💡 Fórmula proposta: `bônus = segundos que sobraram × multiplicador` (protótipo: ×2,5 no fácil, ×2 no médio, ×1,5 no difícil).
  Exemplo da ideia original: prazo de 60 s, entrega em 50 s → sobraram 10 s → **+30 s**.
- 💡 Pedido entregue **depois** do prazo: vale menos pontos (pedido atrasado), mas não tira tempo.

### 3.3 Pontuação
- **Ganha ponto:** entrega feita, entrega antecipada, manobra de risco (lombada), sequência sem erro.
- **Perde ponto:** cair da moto (boca de lobo), passar no cruzamento na hora errada, ser parado na blitz, entregar atrasado, errar o código.
- **Nunca perde vida.** Não existe sistema de vidas.

### 3.4 Gasolina
- A moto gasta gasolina conforme anda (mais ainda acelerando forte).
- **Postos aparecem em ordem/posições aleatórias** a cada partida.
- Abastecer leva **~10 segundos** parado (o relógio da fase continua correndo: é uma escolha de risco).
- **Gasolina zerou = GAME OVER, sem exceção**, com uma **mensagem engraçada** aleatória. Exemplos:
  - "A moto bebeu menos que você no fim de semana, mas acabou primeiro."
  - "Pedido cancelado. Motivo: entregador virou pedestre."
  - "O cliente avaliou: ⭐ — 'veio empurrando'."
  - "Você tinha R$ 3,50 de gasolina e um sonho."

### 3.5 Entrega no portão
1. O entregador chega no endereço e para.
2. **Percalço aleatório:** às vezes o cliente **demora a descer** (espera variável).
3. Quando o cliente aparece, abre um **balão de texto** pedindo o **código do pedido**.
4. O código aparece com **números "quebradiços"** (tremendo, distorcidos ou com falhas) para dificultar a leitura.
5. Acertou → entrega concluída. Errou → perde pontos e tenta de novo.

---

## 4. Modos de dificuldade (a "bag")

A dificuldade é escolhida pela **bag** do entregador:

| Bag | Paródia de | Dificuldade | Efeito |
|---|---|---|---|
| **iFudê** (vermelha, texto branco) | iFood | Fácil | Prazos longos, códigos legíveis, poucos percalços |
| **99 Problemas** (amarela, detalhe preto) | 99 | Médio | Prazos padrão |
| **Kitreta** (verde-água com painel amarelo) | Keeta | Difícil | Prazos curtos, códigos bem quebrados, mais percalços |

Nomes escolhidos pelo grupo. As bags usam só as **cores** dos apps reais, com desenho próprio (sem copiar logo).

### Modos especiais
- **Final de semana:** mais entregas, menos tempo.
- **Domingueiros (Ultra Hard):** exige desempenho quase perfeito; ruas cheias de "domingueiros" atrapalhando.

> ✅ **Marcas reais → paródia** (decidido): as bags viraram iFudê, 99 Problemas e Kitreta.
> 💡 Easter eggs ainda em aberto: sugestões "Zé da Gelada" (Zé Delivery), "Uber Eita" (Uber Eats) e "Rapidi" (Rappi).

---

## 5. Obstáculos e mecânicas de fase

| Obstáculo | Comportamento | Risco / recompensa |
|---|---|---|
| **Chuva** | Clima da fase: freio mais fraco, a moto escorrega | Exige frear antes |
| **Habilitação vencida** | Dispara uma **perseguição temporária de um carro da CET** | Se te alcançar: perde pontos e tempo 💡 |
| **Blitz** | Zona onde é preciso **passar devagar**. Chance baixa de ser parado por alguns segundos; **passar rápido aumenta a chance** | Escolha entre perder tempo freando ou arriscar |
| **Lombada** | Faz a moto **voar** | Alto risco, alta recompensa: pousar bem dá bônus, pousar mal derruba |
| **Cruzamento** | Carros passam em ciclos, **como armadilhas de esmagamento com tempo certo** | Passar na hora errada = perde pontos |
| **Boca de lobo** | Faz a moto **girar** | Se cair, perde pontos |
| **Estrada de terra** | Trecho que **desacelera** a moto | Custo de tempo |
| **Ciclovia (RNG)** | **Chance aleatória** de aparecer uma ciclovia que **corta caminho** | Atalho de sorte |

### Como ficou no jogo (M2)
- **Equilíbrio no ar:** lombada e boca de lobo lançam a moto "instável". No ar, **A / D** (ou **< >** no celular) giram a moto para equilibrar. Pousar com mais de ~45° de inclinação = **queda** (-40 pts na lombada, -30 na boca de lobo) e ~1,6 s caído.
  - O giro é **sensível** (segurar a tecla direto passa do ponto: é preciso dar toques) e a moto **balança** um pouco no ar, diferente a cada voo.
  - No ar a gravidade é menor (a moto "flutua"): ~1,3 s de voo e ~270 px de altura na lombada em velocidade máxima.
- **Lombada:** acima de ~200 px/s a moto voa; quanto mais rápido, mais alto e mais ela gira. Normalmente empina (bico para cima), mas em 25% das vezes **embica** para a frente. Pouso limpo dá bônus que cresce com o tempo no ar (×1,5 se o pouso for quase reto). Devagar, só dá um solavanco.
- **Boca de lobo:** rápido, a moto pula e gira para um lado aleatório; devagar, só perde velocidade.
- **Estrada de terra:** velocidade máxima ×0,55 e aceleração ×0,6. O carro da CET também fica lento na terra.
- **Ciclovia:** 4 trechos possíveis, cada um com 50% de chance de existir na partida (pelo menos um sempre aparece). Velocidade ×1,35.
- **Cruzamento:** semáforo verde (2,6 s), amarelo piscando + faróis no fundo da rua (1 s), carro atravessando (1,4 s). Ser pego pelo carro = -50 pts, moto derrubada e empurrada para trás.
- **Blitz:** a chance de ser parado é sorteada no meio da blitz. Devagar (até ~260 px/s, metade da velocidade máxima) é só a chance base da dificuldade; acima disso sobe até +65%. Parado = 3 a 5 s.
- **Chuva:** sorteada por partida (25% / 35% / 50%). Freio com 40% da força.
- **CNH vencida → CET:** sorteada por partida (50% / 75% / 100%), dispara entre 15% e 40% do tempo da fase. O carro surge atrás da moto e persegue por 22 s (82% / 88% / 94% da velocidade da moto). Pegou = -60 pts, -8 s e 3 s parado. Fugiu = +50 pts. A perseguição pausa enquanto o cliente digita o código.
- **Mapa:** dobrou de tamanho (14.000 px), com 5 restaurantes, 15 casas, 6 vagas de posto (3 ativas por partida), platôs/viadutos e prédios/lojas/bares/borracharias/terrenos preenchendo a rua. Desde o M2.5 o mapa é **gerado proceduralmente** (seção 5.1).

### 5.1 Geração procedural do mapa
Cada partida gera um mapa novo a partir de uma **semente** (número). A mesma semente sempre gera o mesmo mapa: a tela de fim mostra o "Mapa nº", e **Jogar de novo** repete o mesmo mapa. O código fica em `src/gerador_fase.gd`.

**Ordem de montagem:** chão (2 a 4 platôs/viadutos) → obstáculos de pista → restaurantes, postos e casas → obstáculos sólidos → trechos de ciclovia.

**Quantidade por mapa** (o mínimo é garantido; os extras só entram se couberem):

| Lombada | Boca de lobo | Terra | Cruzamento | Blitz | Ciclovia (candidatas) | Sólidos |
|---|---|---|---|---|---|---|
| 3–5 | 3–5 | 1–3 | 2–3 | 1–2 | até 4 | até 9 |

**Regras de distância** (borda a borda, em px; a moto anda a ~520 px/s no máximo). Servem para cada obstáculo ter **embalo antes e espaço depois**, e o impacto dele não se misturar com o de outro:

| | Lombada / boca | Blitz | Cruzamento | Terra |
|---|---|---|---|---|
| **Lombada / boca** | 550–650 | 750 | 550 | 450 |
| **Blitz** | 750 | 2000 | 750 | 650 |
| **Cruzamento** | 550 | 750 | 1200 | 450 |
| **Terra** | 450 | 650 | 450 | 1200 |

Outras regras:
- Nada perigoso nos primeiros 600 px (onde a moto nasce) nem nos últimos 300.
- Nenhum obstáculo ou endereço em rampa. Lombada e boca ficam a 200 px de rampas (pista plana para voar e pousar).
- Cruzamento nunca em cima de platô/viaduto.
- Obstáculos sólidos ficam a 330 px de lombada/boca (fora do pouso mais comum) e a 300 px da blitz.
- Endereços (restaurante, casa, posto) ficam espalhados: a rua é dividida em faixas iguais e cada endereço cai numa faixa. A numeração das casas cresce da esquerda para a direita.
- Ciclovia e estrada de terra podem passar na frente de casas.

Todas essas distâncias ficam na tabela `FOLGAS` do gerador, para o grupo ajustar.
> 💡 Para testar um mapa específico: rodar o jogo com `-- --semente=N`.

### Percalços aleatórios (por pedido)
- **Pedido atrasado:** o restaurante demora para liberar.
- **Cliente demora no portão:** espera aleatória na entrega.

---

## 6. Progressão

### 6.1 Dinheiro
- No fim de cada fase vem o **acerto do turno**:
  - **Venceu:** R$ 1 a cada 10 pontos (inclui o bônus de tempo que sobrou).
  - **Perdeu:** só R$ 8 por entrega feita (a taxa de entrega). Assim, perder não zera o esforço, mas vencer paga bem mais.
- Rejogar uma fase vencida também paga, então quem travar numa fase pode voltar, juntar dinheiro e melhorar a moto.
- Na prática (bot no médio, sem melhorias), uma fase vencida paga de ~R$ 80 (fase 1) a ~R$ 230 (fase 5).
- Lombada e boca de lobo só dão bônus **uma vez por pedido** cada, para não dar para ficar indo e voltando juntando pontos.

### 6.2 Oficina (melhorias da moto)
Aberta pelo menu de fases ou pela tela de fim. É uma cena própria: fundo da oficina em pixel art, a **mecânica Tati** e o entregador conversando, e o painel de melhorias à direita.
- **A Tati reage ao jogador:**
  - **Ao chegar:** comenta o estado da moto (nenhuma melhoria, algumas, quase todas, tudo no máximo), o saldo e a bag escolhida.
  - **Ao passar o mouse numa melhoria:** explica o que ela faz, com uma fala diferente para cada nível atual, e diz o preço.
  - **Depois de uma compra:** comemora (polegar para cima) com uma fala sobre a peça nova.
  - **Sem dinheiro:** reclama do "fiado". A falta de dinheiro não bloqueia o botão: tentar comprar faz a Tati responder.
- Os personagens são desenhados por código em baixa resolução e ampliados 4x sem suavizar, para combinar com o fundo. Têm respiração, piscada, boca mexendo enquanto falam e expressões (neutra, feliz, brava).

Cada melhoria tem **3 níveis**, a **R$ 50, R$ 100 e R$ 180** (R$ 1.650 para comprar tudo; uma campanha vencida de primeira rende ~R$ 650 no médio).

> Teste do bot: no **difícil** sem melhorias ele trava a partir da fase 2 ou 3; com tudo no nível 3, vence as 5. No **médio** vence as 5 até sem melhorias, que ali servem de folga para jogador humano.

| Melhoria | Efeito por nível | Por que ajuda |
|---|---|---|
| **Motor** | +7% de velocidade máxima, +10% de arrancada | Chega antes, sobra mais prazo. Lombada em alta também lança mais longe! |
| **Freio** | +18% de força de freio | Para no portão e na blitz sem passar do ponto; compensa a chuva |
| **Tanque** | +25% de gasolina | Menos paradas no posto (encher do zero demora mais) |
| **Amortecedor** | Aguenta pousar ~6° mais torto sem cair (45° → 63° no nível 3) | Perdoa erros no equilíbrio do ar |
| **Bag térmica** | +12% de prazo em cada pedido | Mais pedidos entregues adiantados, logo mais tempo de volta |

- As melhorias são **por bag**: cada campanha tem a sua moto.
- 💡 **Upgrade da bag (capacidade):** carregar mais de um pedido ao mesmo tempo ficou para depois, porque muda o loop de pedidos.
- **Conquistas (achievements)** por habilidade. 💡 Ideias: "Voo da lombada" (pousar 5 lombadas seguidas), "Nem vi a CET" (fugir sem ser pego), "Tanque na reserva" (terminar a fase com menos de 5% de gasolina), "Código de primeira" (10 códigos sem erro).

> ❓ A lista original tem "skill achievement" e "skill" separados. "Skill" seriam **habilidades ativas** do entregador (ex.: turbo, empinar)? Falta definir.

---

## 7. Easter eggs (apenas visuais)

- **Menu → ponto específico → libera a skin "Zé Delivery"** (só visual).
- Aparições visuais de **Uber Eats** e **Rappi** pelo cenário (motos de fundo, placas).
- (Mesma observação da seção 4 sobre marcas reais.)

---

## 8. Direção de arte e som

- **Paleta:** laranja (destaques, UI, a bag), cinzas (asfalto, prédios), preto (silhuetas, contornos), vermelho (perigo, CET, alertas).
- Estilo *gritty*: céu poluído de fim de tarde, poste piscando, pichação, poças.
- **Arte 100% desenhada por código** (decisão do grupo: **sem sprites**, que tomariam tempo demais). A única exceção é a fonte pixelada *Silkscreen Bold* (licença OFL).
- **Texturas "sujas"** (`src/sujeira.gd`, `src/ground.gd`):
  - **Paredes:** umidade subindo do chão, escorridos de chuva e ferrugem, manchas de mofo, rachaduras e reboco caído com tijolo aparente.
  - **Pichação:** tags em altura de mão e pixo paulistano (letras altas e retas) no alto dos prédios, mais lambe-lambe rasgado.
  - **Rua:** lixo encostado nas paredes (sacos pretos, papelão, latinhas); calçada rachada com chiclete e mato nas frestas; asfalto com remendos, manchas de óleo e poças refletindo as luzes.
  - **Postes:** fiação pendurada entre os postes, "gatos" de fio embolado, transformadores, tênis pendurado no fio e lâmpadas com defeito piscando.
- **Animações:** rodas girando; piloto inclinando (para a frente ao acelerar, para trás ao frear); moto afundando a frente na freada e empinando de leve na arrancada; fumaça do escapamento; poeira da roda na estrada de terra; moto piscando enquanto está caída; cliente acenando no portão; giroflex da CET com feixes girando; semáforo piscando; chuva; números do código tremendo.
- **Feedback visual:** tremor de tela na queda, no cruzamento, na multa da CET e em pousos fortes; nuvem de poeira no pouso; faíscas na queda; confete e "+pontos / +segundos" subindo na entrega; pontos ganhos e perdidos flutuando sobre a moto.
- **Som:** tudo sintetizado por código (`src/som.gd`), sem arquivos de áudio de terceiros.
  - **Trilhas:** menu calmo de fim de tarde (92 BPM) e **funk paulista** na partida (130 BPM: 808 no ritmo do tamborzão, palmas, "tuim" e synth "automotivo"). A música abaixa enquanto o cliente digita o código e enquanto a CET persegue.
  - **Efeitos:** pulo, tranco na lombada, pouso, pouso perfeito, queda, buzina no cruzamento, apito da blitz, multa, coleta, entrega (caixa registradora), código (bipe/erro), alerta de reserva, tanque cheio, compra na oficina, clique, vinhetas de vitória e derrota.
  - **Sons contínuos:** motor (o tom sobe com a velocidade), freio, vento no voo, chuva, sirene da CET, bomba do posto.
  - **Tecla M** liga/desliga todo o som.

---

## 9. Fora do escopo por enquanto

- **Mapas diferentes** (vários bairros/cidades, com outro visual): não atacar ainda. O layout da rua já é procedural (seção 5.1).

---

## 10. Plano de desenvolvimento

| Etapa | Conteúdo |
|---|---|
| **M1 — Protótipo do núcleo** ✅ | Moto (aceleração, freio, pulo), uma fase, restaurante → cliente, prazo + relógio + bônus, gasolina + posto, código no portão, pontuação, HUD, game over/vitória |
| **M2 — Obstáculos** ✅ | Lombada, boca de lobo, estrada de terra, cruzamento, blitz, chuva, CET, ciclovia, mapa maior |
| **M2.5 — Mapa procedural** ✅ | Rua gerada por semente, com regras de distância entre obstáculos |
| **M3 — Estrutura de jogo** | ~~Menu, escolha da bag (dificuldade)~~ (feito no M1), ~~várias fases~~ (campanha de 5 fases), ~~pausa e volta ao menu~~, modos final de semana/domingueiros |
| **M4 — Progressão** | ~~Oficina de upgrades~~ (dinheiro + 5 melhorias), conquistas, ranking local |
| **M5 — Arte e polimento** | ~~Texturas sujas~~, ~~animações e efeitos~~, ~~som~~ (sintetizado por código), ~~fonte pixelada~~, easter eggs. Sprites: descartados, a arte fica desenhada por código |
