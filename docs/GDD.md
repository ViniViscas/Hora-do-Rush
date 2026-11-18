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
- 💡 Fórmula proposta: `bônus = segundos que sobraram × multiplicador` (protótipo: ×3 no fácil, ×2 no médio, ×1,5 no difícil).
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
- **Trilha sonora:** fica para depois.

---

## 9. Fora do escopo por enquanto

- **Mapas diferentes** (vários bairros/cidades): não atacar ainda.
- Trilha sonora.

---

## 10. Plano de desenvolvimento

| Etapa | Conteúdo |
|---|---|
| **M1 — Protótipo do núcleo** | Moto (aceleração, freio, pulo), uma fase, restaurante → cliente, prazo + relógio + bônus, gasolina + posto, código no portão, pontuação, HUD, game over/vitória |
| **M2 — Obstáculos** | Lombada, boca de lobo, estrada de terra, cruzamento, blitz, chuva, CET |
| **M3 — Estrutura de jogo** | Menu, escolha da bag (dificuldade), várias fases, modos final de semana/domingueiros |
| **M4 — Progressão** | Oficina de upgrades, conquistas, ranking local |
| **M5 — Arte e polimento** | Sprites finais, efeitos, easter eggs, som |
