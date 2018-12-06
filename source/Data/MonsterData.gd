extends Node

# Map type => variation type => monsters => data
const MONSTER_DATA = {
	"Forest": {
		"Slime": {
		    "Gold Slime": {
		        "type": "Gold Slime",
		        "weight": 70,
		        "health": 70,
		        "strength": 15,
		        "defense": 17,
		        "turns": 1,
		        "experience points": 14,
		        
		        "skill_probability": 40, # 40 = 40%
		        "skills": {
		            "chomp": 100
		        }
		    },
		    "Vampire Bat": {
		        "type": "Vampire Bat",
		        "weight": 30,
		        "health": 85,
		        "strength": 24,
		        "defense": 15,
		        "turns": 1,
		        "experience points": 11,
		        "vampire multiplier": 1.1, # normal is 1.5
		        
		        "skill_probability": 20,
		        "skills": {
		            "vampire": 100 
		        }
		    } 
		},
		"Frost": {
		    "Howler": {
		        "type": "Howler",
		        "weight": 30,
		        "health": 90,
		        "strength": 28,
		        "defense": 16,
		        "turns": 2,
		        "experience points": 17,
		        
		        "skill_probability": 40, # 40 = 40%
		        "skills": {
		            "roar": 100
		        },
		        # Override skill messages with custom values
		        "skill_messages": {
		            "roar": "howls! Attack up by {amount}!"
		        }
		    },
		    "Ice Terrapin": {
		        "type": "Ice Terrapin",
		        "weight": 60,
		        "health": 65,
		        "strength": 20,
		        "defense": 20,
		        "turns": 2,
		        "experience points": 13,
		        
		        "skill_probability": 50, # 40 = 40%
		        "skills": {
		            "freeze": 100
		        }
		    }
		}
	},
	"Cave": {
		"River": {
		    "Clawomatic": {
		        "type": "Clawomatic",
		        "weight": 50,
		        "health": 150,
		        "strength": 30,
		        "defense": 10,
		        "turns": 1,
		        "experience points": 18,
		        
		        "skill_probability": 50, # 40 = 40%
		        "skills": {
		            "harden": 100 
		        }
		    },
		    "WingBeak": {
		        "type": "WingBeak",
		        "weight": 50,
		        "health": 110,
		        "strength": 20,
		        "defense": 16,
		        "turns": 1,
		        "experience points": 16,
		        
		        "skill_probability": 50, # 40 = 40%
		        "skills": {
		            "roar": 100 
		        }
		    }
		},
		"Lava": {
		    "Flame Tail": {
		        "type": "Flame Tail",
		        "weight": 60,
		        "health": 110,
		        "strength": 35,
		        "defense": 10,
		        "turns": 1,
		        "experience points": 13,
		        
		        "skill_probability": 30, # 40 = 40%
		        "skills": {
		            "poison": 100 
		        }
		    },
		    "Red Scorpion": {
		        "type": "Red Scorpion",
		        "weight": 40,
		        "health": 80,
		        "strength": 25,
		        "defense": 17,
		        "turns": 1,
		        "experience points": 13,
		        
		        "skill_probability": 25,
		        "skills": {
		            "armour break": 100
		        }
		    }
		}
	},
	"Dungeon": {
		"Castle": {
			"Foot Soldier": {
				"type": "FootSoldier",
		        "weight": 70,
		        "health": 90,
		        "strength": 19,
		        "defense": 14,
		        "turns": 1,
		        "experience points": 17,
		        
		        "skill_probability": 65, # 40 = 40%
		        "skills": {
		            "chomp": 100,
		        },
		        "skill_messages": {
		            "chomp": "bashes you with his shield! {damage} damage!"
		        }
			},
			"Skelly": {
				"type": "Skelly",
		        "weight": 30,
		        "health": 110,
		        "strength": 24,
		        "defense": 13,
		        "turns": 1,
		        "experience points": 20,
		        
		        "skill_probability": 50,
		        "skills": {
		            "heal": 100
		        },
		        "skill_messages": {
		            "heal": "regenerates its bones! Healed {amount} health!"
		        }
			}
		}
	}
}