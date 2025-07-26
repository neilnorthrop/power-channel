document.addEventListener('DOMContentLoaded', () => {
    const levelSpan = document.getElementById('level');
    const experienceSpan = document.getElementById('experience');
    const skillPointsSpan = document.getElementById('skill-points');
    const resourcesDiv = document.getElementById('resources');
    const actionsDiv = document.getElementById('actions');
    const skillsDiv = document.getElementById('skills');
    const inventoryDiv = document.getElementById('inventory');
    const craftingDiv = document.getElementById('crafting');
    const buildingsDiv = document.getElementById('buildings');

    // Fetches the current user's data from the server.
    // Typically used to retrieve user information for display or further processing
    // within the application interface.
    // Returns a Promise that resolves with the user data.
    const fetchUser = () => {
        fetch('/api/v1/user', {
        headers: {
            'Authorization': `Bearer <%= JsonWebToken.encode(user_id: current_user.id) %>`
        }
        })
        .then(response => response.json())
        .then(data => {
        levelSpan.innerText = data.data.attributes.level;
        experienceSpan.innerText = data.data.attributes.experience;
        skillPointsSpan.innerText = data.data.attributes.skill_points;
        });
    };

    // Fetches resource data from the server or API.
    // Typically used to update the application's state with the latest resource information.
    // This function does not take any parameters and returns a promise that resolves when the data is fetched.
    const fetchResources = () => {
        fetch('/api/v1/resources', {
        headers: {
            'Authorization': `Bearer <%= JsonWebToken.encode(user_id: current_user.id) %>`
        }
        })
        .then(response => response.json())
        .then(data => {
        resourcesDiv.innerHTML = '';
        data.data.forEach(resource => {
            const resourceDiv = document.createElement('div');
            resourceDiv.innerHTML = `<strong>${resource.attributes.name}:</strong> ${resource.attributes.base_amount}`;
            resourcesDiv.appendChild(resourceDiv);
        });
        });
    };

    // Fetches available actions from the server and updates the application state accordingly.
    // Typically used to retrieve the latest set of actions a user can perform in the game.
    // Handles asynchronous requests and manages loading or error states as needed.
    const fetchActions = () => {
        fetch('/api/v1/actions', {
        headers: {
            'Authorization': `Bearer <%= JsonWebToken.encode(user_id: current_user.id) %>`
        }
        })
        .then(response => response.json())
        .then(data => {
        actionsDiv.innerHTML = '';
        const actions = data.included.filter(inc => inc.type === 'action');
        data.data.forEach(userAction => {
            const action = actions.find(a => a.id === userAction.relationships.action.data.id);
            const actionDiv = document.createElement('div');
            const actionButton = document.createElement('button');
            actionButton.innerText = action.attributes.name;
            actionButton.addEventListener('click', () => {
            performAction(action.id);
            });
            actionDiv.appendChild(actionButton);

            const upgradeButton = document.createElement('button');
            upgradeButton.innerText = 'Upgrade';
            upgradeButton.addEventListener('click', () => {
            upgradeAction(userAction.id);
            });
            actionDiv.appendChild(upgradeButton);

            const cooldownSpan = document.createElement('span');
            cooldownSpan.id = `cooldown-${userAction.id}`;
            actionDiv.appendChild(cooldownSpan);

            actionsDiv.appendChild(actionDiv);

            updateCooldown(userAction);
        });
        });
    };

    // Updates the cooldown timer for a given user action.
    // @param userAction [Object] The action performed by the user that triggers a cooldown update.
    // @return [void]
    const updateCooldown = (userAction) => {
        const cooldownSpan = document.getElementById(`cooldown-${userAction.id}`);
        if (!cooldownSpan) return;

        if (userAction.attributes.last_performed_at) {
        const lastPerformedAt = new Date(userAction.attributes.last_performed_at);
        const cooldown = userAction.attributes.cooldown;
        const now = new Date();
        const diff = (now - lastPerformedAt) / 1000;

        if (diff < cooldown) {
            const remaining = Math.ceil(cooldown - diff);
            cooldownSpan.innerText = ` (Cooldown: ${remaining}s)`;
            setTimeout(() => updateCooldown(userAction), 1000);
        } else {
            cooldownSpan.innerText = '';
        }
        } else {
        cooldownSpan.innerText = '';
        }
    };

    // Fetches the list of skills from the server or API.
    // Typically used to retrieve and update the skills data in the application state.
    // Returns a Promise that resolves with the fetched skills data.
    const fetchSkills = () => {
        fetch('/api/v1/skills', {
        headers: {
            'Authorization': `Bearer <%= JsonWebToken.encode(user_id: current_user.id) %>`
        }
        })
        .then(response => response.json())
        .then(data => {
        skillsDiv.innerHTML = '';
        data.data.forEach(skill => {
            const skillDiv = document.createElement('div');
            skillDiv.innerHTML = `<strong>${skill.attributes.name}</strong> (${skill.attributes.cost} SP): ${skill.attributes.description}`;
            const unlockButton = document.createElement('button');
            unlockButton.innerText = 'Unlock';
            unlockButton.addEventListener('click', () => {
            unlockSkill(skill.id);
            });
            skillDiv.appendChild(unlockButton);
            skillsDiv.appendChild(skillDiv);
        });
        });
    };

    // Fetches the player's inventory data from the server.
    // Typically used to update the UI with the latest inventory state.
    // Returns a promise that resolves with the inventory data.
    const fetchInventory = () => {
        fetch('/api/v1/items', {
        headers: {
            'Authorization': `Bearer <%= JsonWebToken.encode(user_id: current_user.id) %>`
        }
        })
        .then(response => response.json())
        .then(data => {
        inventoryDiv.innerHTML = '';
        data.data.forEach(item => {
            const itemDiv = document.createElement('div');
            itemDiv.innerHTML = `<strong>${item.attributes.name}</strong>: ${item.attributes.description}`;
            const useButton = document.createElement('button');
            useButton.innerText = 'Use';
            useButton.addEventListener('click', () => {
            useItem(item.id);
            });
            itemDiv.appendChild(useButton);
            inventoryDiv.appendChild(itemDiv);
        });
        });
    };

    const fetchCrafting = () => {
        fetch('/api/v1/crafting', {
        headers: {
            'Authorization': `Bearer <%= JsonWebToken.encode(user_id: current_user.id) %>`
        }
        })
        .then(response => response.json())
        .then(data => {
        craftingDiv.innerHTML = '';
        const items = data.included.filter(inc => inc.type === 'item');
        data.data.forEach(recipe => {
            const item = items.find(i => i.id === recipe.relationships.item.data.id);
            const recipeDiv = document.createElement('div');
            recipeDiv.innerHTML = `<strong>${item.attributes.name}</strong>: `;
            const craftButton = document.createElement('button');
            craftButton.innerText = 'Craft';
            craftButton.addEventListener('click', () => {
            craftItem(recipe.id);
            });
            recipeDiv.appendChild(craftButton);
            craftingDiv.appendChild(recipeDiv);
        });
        });
    };

    // Fetches building data from the server.
    // Typically used to retrieve and update the list of buildings displayed in the UI.
    // Handles asynchronous requests and updates the relevant state or DOM elements upon completion.
    const fetchBuildings = () => {
        fetch('/api/v1/buildings', {
        headers: {
            'Authorization': `Bearer <%= JsonWebToken.encode(user_id: current_user.id) %>`
        }
        })
        .then(response => response.json())
        .then(data => {
        buildingsDiv.innerHTML = '';
        data.data.forEach(building => {
            const buildingDiv = document.createElement('div');
            buildingDiv.innerHTML = `<strong>${building.attributes.name}</strong> (Level ${building.attributes.level}): ${building.attributes.description}`;
            const upgradeButton = document.createElement('button');
            upgradeButton.innerText = 'Upgrade';
            upgradeButton.addEventListener('click', () => {
            upgradeBuilding(building.id);
            });
            buildingDiv.appendChild(upgradeButton);
            buildingsDiv.appendChild(buildingDiv);
        });
        });
    };

    // Performs a specified game action based on the provided actionId.
    // @param actionId [Integer, String] The unique identifier of the action to perform.
    // @return [void]
    // @example
    //   performAction(1) # Executes the action with ID 1
    const performAction = (actionId) => {
        fetch('/api/v1/actions', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer <%= JsonWebToken.encode(user_id: current_user.id) %>`
        },
        body: JSON.stringify({ action_id: actionId })
        })
        .then(response => response.json())
        .then(data => {
        if (data.error) {
            alert(data.error);
        } else {
            alert(data.message);
            fetchResources();
            fetchUser();
        }
        });
    };

    // Sends a PATCH request to upgrade a specific action by its ID.
    // 
    // @param actionId [Integer, String] The unique identifier of the action to upgrade.
    // @return [Promise] The fetch API promise resolving to the server's response.
    // 
    // The request includes a JSON Web Token for user authentication in the Authorization header.
    const upgradeAction = (actionId) => {
        fetch(`/api/v1/actions/${actionId}`, {
        method: 'PATCH',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer <%= JsonWebToken.encode(user_id: current_user.id) %>`
        }
        })
        .then(response => response.json())
        .then(data => {
        if (data.error) {
            alert(data.error);
        } else {
            alert(data.message);
        }
        });
    };

    const unlockSkill = (skillId) => {
        fetch('/api/v1/skills', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer <%= JsonWebToken.encode(user_id: current_user.id) %>`
        },
        body: JSON.stringify({ skill_id: skillId })
        })
        .then(response => response.json())
        .then(data => {
        if (data.error) {
            alert(data.error);
        } else {
            alert(data.message);
            fetchUser();
        }
        });
    };

    /**
     * useItem is a JavaScript function that sends a POST request to the server to use a specific item.
     * @param {number} itemId - The unique identifier of the item to be used.
     * The function makes a fetch request to the endpoint `/api/v1/items/:itemId/use`,
     * including a Bearer token for authorization in the request headers.
     */
    const useItem = (itemId) => {
        fetch(`/api/v1/items/${itemId}/use`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer <%= JsonWebToken.encode(user_id: current_user.id) %>`
        }
        })
        .then(response => response.json())
        .then(data => {
        if (data.error) {
            alert(data.error);
        } else {
            alert(data.message);
            fetchInventory();
        }
        });
    };

    const craftItem = (recipeId) => {
        fetch('/api/v1/crafting', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer <%= JsonWebToken.encode(user_id: current_user.id) %>`
        },
        body: JSON.stringify({ recipe_id: recipeId })
        })
        .then(response => response.json())
        .then(data => {
        if (data.error) {
            alert(data.error);
        } else {
            alert(data.message);
            fetchResources();
            fetchInventory();
        }
        });
    };

    const upgradeBuilding = (buildingId) => {
        fetch(`/api/v1/buildings/${buildingId}`, {
        method: 'PATCH',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer <%= JsonWebToken.encode(user_id: current_user.id) %>`
        }
        })
        .then(response => response.json())
        .then(data => {
        if (data.error) {
            alert(data.error);
        } else {
            alert(data.message);
            fetchBuildings();
        }
        });
    };

    fetchUser();
    fetchResources();
    fetchActions();
    fetchSkills();
    fetchInventory();
    fetchCrafting();
    fetchBuildings();
});