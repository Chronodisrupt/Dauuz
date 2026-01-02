// Simulates daily DUZ distribution for early community

const users = {
  "Disrup": 0,
  "Alice": 0,
  "Bob": 0
};

// Reward system
const rewards = {
  referral: 0.1,
  awareness: 0.125,  // max 4/day
  survey: 0.25,      // once per user
  innovative: 10,
  groundbreaking: 100
};

const dailyAwarenessLimit = 4;
const maxDailyDUZ = 1; // max per user

function earnDUZ(user, task, quantity = 1) {
  if (!(task in rewards)) {
    console.log("Invalid task");
    return;
  }

  let reward = rewards[task] * quantity;
  reward = Math.min(reward, maxDailyDUZ); // Cap daily DUZ
  users[user] += reward;
  console.log(`${user} earned ${reward} DUZ for ${task}.`);
}

// Example usage
earnDUZ("Alice", "referral");
earnDUZ("Alice", "awareness", 3);
earnDUZ("Bob", "survey");
earnDUZ("Disrup", "innovative");

console.log("\nCurrent Balances:");
for (const [user, balance] of Object.entries(users)) {
  console.log(`${user}: ${balance} DUZ`);
}
