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
| **Plataforma alvo** | PC (Windows), com possível exportação para a web |
| **Tom visual** | *Gritty*, urbano, cansado: paleta **laranja, cinza, preto e vermelho** |

**Pilares**
1. **Correria com consequência:** velocidade dá tempo, mas os obstáculos punem quem corre demais.
2. **Perde ponto, não perde vida:** errar custa pontuação e tempo. O único game over "seco" é a **gasolina acabar**.
3. **Humor de rua:** situações reconhecíveis do dia a dia de entregador (cliente que não desce, blitz, código do pedido).

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
- **A fase define o número de pedidos** (ex.: fase 1 = 3 entregas, fase 2 = 5…).
- **A dificuldade define o tempo** disponível.

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

| Bag | Dificuldade | Efeito 💡 |
|---|---|---|
| Bag laranja/vermelha (paródia de app 1) | Fácil | Prazos longos, códigos legíveis, poucos percalços |
| Bag amarela (paródia de app 2) | Médio | Prazos padrão |
| Bag preta/amarela (paródia de app 3) | Difícil | Prazos curtos, códigos bem quebrados, mais percalços |

Referências originais da equipe: iFood (fácil), 99 (médio), Keeta (difícil).

### Modos especiais
- **Final de semana:** mais entregas, menos tempo.
- **Domingueiros (Ultra Hard):** exige desempenho quase perfeito; ruas cheias de "domingueiros" atrapalhando.

> ❓ **Marcas reais:** usar nomes e logos de verdade (iFood, 99, Keeta, Zé Delivery, Uber Eats, Rappi) pode dar problema mesmo num trabalho acadêmico, principalmente se o jogo for publicado.
> 💡 Proposta: nomes de **paródia** com as mesmas cores (ex.: "iFominha", "Noventa e Nove", "Kita", "Zé do Delivery"). A referência continua clara sem copiar logo.

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
- **Lombada:** acima de ~200 px/s a moto voa; quanto mais rápido, mais alto e mais ela empina. Pouso limpo dá bônus que cresce com o tempo no ar (×1,5 se o pouso for quase reto). Devagar, só dá um solavanco.
- **Boca de lobo:** rápido, a moto pula e gira para um lado aleatório; devagar, só perde velocidade.
- **Estrada de terra:** velocidade máxima ×0,55 e aceleração ×0,6. O carro da CET também fica lento na terra.
- **Ciclovia:** 4 trechos possíveis, cada um com 50% de chance de existir na partida (pelo menos um sempre aparece). Velocidade ×1,35.
- **Cruzamento:** semáforo verde (2,6 s), amarelo piscando + faróis no fundo da rua (1 s), carro atravessando (1,4 s). Ser pego pelo carro = -50 pts, moto derrubada e empurrada para trás.
- **Blitz:** a chance de ser parado é sorteada no meio da blitz. Devagar (até ~180 px/s) é só a chance base da dificuldade; acima disso sobe até +65%. Parado = 3 a 5 s.
- **Chuva:** sorteada por partida (25% / 35% / 50%). Freio com 40% da força.
- **CNH vencida → CET:** sorteada por partida (50% / 75% / 100%), dispara entre 15% e 40% do tempo da fase. O carro surge atrás da moto e persegue por 22 s (82% / 88% / 94% da velocidade da moto). Pegou = -60 pts, -8 s e 3 s parado. Fugiu = +50 pts. A perseguição pausa enquanto o cliente digita o código.
- **Mapa:** dobrou de tamanho (14.000 px), com 5 restaurantes, 15 casas, 6 vagas de posto (3 ativas por partida), platôs/viadutos e prédios/lojas/bares/borracharias/terrenos preenchendo a rua. Desde o M2.5 o mapa é **gerado proceduralmente** (seção 5.1).

### 5.1 Geração procedural do mapa
Cada partida gera um mapa novo a partir de uma **semente** (número). A mesma semente sempre gera o mesmo mapa: a tela de fim mostra o "Mapa nº", e **Jogar de novo** repete o mesmo mapa. O código fica em `scripts/gerador_fase.gd`.

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

- **Upgrades da moto:** velocidade, freio, tanque (gasolina).
- **Upgrades da bag:** capacidade (carregar mais de um pedido ao mesmo tempo).
- 💡 Comprados com o dinheiro/pontos ganhos nas fases, numa **tela de oficina** entre fases.
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
- 💡 Texturas "sujas" (manchas, reboco caído, tijolo aparente, lixo na calçada, fios nos postes): **adiado** a pedido do grupo, entra no M5.
- **Trilha sonora:** fica para depois.

---

## 9. Fora do escopo por enquanto

- **Mapas diferentes** (vários bairros/cidades, com outro visual): não atacar ainda. O layout da rua já é procedural (seção 5.1).
- Trilha sonora.

---

## 10. Plano de desenvolvimento

| Etapa | Conteúdo |
|---|---|
| **M1 — Protótipo do núcleo** ✅ | Moto (aceleração, freio, pulo), uma fase, restaurante → cliente, prazo + relógio + bônus, gasolina + posto, código no portão, pontuação, HUD, game over/vitória |
| **M2 — Obstáculos** ✅ | Lombada, boca de lobo, estrada de terra, cruzamento, blitz, chuva, CET, ciclovia, mapa maior |
| **M2.5 — Mapa procedural** ✅ | Rua gerada por semente, com regras de distância entre obstáculos |
| **M3 — Estrutura de jogo** | ~~Menu, escolha da bag (dificuldade)~~ (feito no M1), várias fases, modos final de semana/domingueiros |
| **M4 — Progressão** | Oficina de upgrades, conquistas, ranking local |
| **M5 — Arte e polimento** | Sprites finais, texturas sujas, efeitos, easter eggs, som |
