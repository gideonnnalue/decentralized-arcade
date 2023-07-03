// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract DAM {
    enum GameStatus {
        CREATED,
        PLAYING,
        FINISHED
    }

    struct Game {
        uint gameID;
        uint maxPlayers;
        uint minPlayers;
        uint numPlayers;
        uint matchCost;
        uint totalAmount;
        address[] playerAddresses;
        uint depositTimeout;
        GameStatus status;
        address winner;
        mapping(address => bool) hasPaid;
        mapping(address => address) playerSubmissions;
        bool hasConflict;
        bool isPayoutDone;
        address[] paidAddresses;
    }

    mapping(uint => Game) game;
    uint nextLobbyId;

    event PlayerJoined(
        address indexed playerAddress,
        uint timestamp,
        address[] joinedPlayers
    );

    event GameEnded(
        uint indexed lobbyId,
        uint indexed gameId,
        uint timestamp,
        address unverifiedWinner
    );
    event WinnerVerification(
        uint indexed lobbyId,
        uint indexed gameId,
        uint timestamp,
        address user,
        address winner
    );

    function createLobby(
        uint gameID,
        uint maxPlayers,
        uint minPlayers,
        uint matchCost,
        address[] memory playerAddresses,
        uint depositTimeout
    ) public payable {
        Game storage newGame = game[nextLobbyId];
        newGame.gameID = gameID;
        newGame.maxPlayers = maxPlayers;
        newGame.minPlayers = minPlayers;
        newGame.numPlayers = 1;
        newGame.playerAddresses = playerAddresses;
        newGame.playerAddresses.push(payable(msg.sender));
        newGame.depositTimeout = depositTimeout;
        newGame.matchCost = matchCost;
        newGame.status = GameStatus.CREATED;

        nextLobbyId++;
    }

    function joinGame(uint lobbyID, uint gameID) public payable {
        Game storage currentGame = game[lobbyID];
        require(currentGame.gameID != 0, "The game lobby does not exist");
        require(currentGame.gameID == gameID, "Invalid game Id");
        require(
            currentGame.matchCost == msg.value,
            "You have sent an invalid amount for this session"
        );
        require(
            block.timestamp < currentGame.depositTimeout,
            "You can no longer deposit"
        );
        require(
            currentGame.status == GameStatus.CREATED,
            "The game is already started or has ended"
        );

        currentGame.paidAddresses.push(msg.sender);
        currentGame.hasPaid[msg.sender] = true;
        currentGame.numPlayers++;
        currentGame.totalAmount += msg.value;

        emit PlayerJoined(
            msg.sender,
            block.timestamp,
            currentGame.paidAddresses
        );
    }

    function verifyWinner(uint lobbyID, uint gameID, address winner) public {
        Game storage currentGame = game[lobbyID];
        require(currentGame.gameID != 0, "The game lobby does not exist");
        require(currentGame.gameID == gameID, "Invalid game Id");
        require(
            currentGame.status != GameStatus.FINISHED,
            "The game is already started or has ended"
        );

        if (winner != currentGame.winner) {
            currentGame.hasConflict = true;
        }
        currentGame.playerSubmissions[msg.sender] = winner;
        emit WinnerVerification(
            lobbyID,
            gameID,
            block.timestamp,
            msg.sender,
            winner
        );
    }

    function endGame(uint lobbyID, uint gameID, address winner) public {
        Game storage currentGame = game[lobbyID];
        require(currentGame.gameID != 0, "The game lobby does not exist");
        require(currentGame.gameID == gameID, "Invalid game Id");
        require(
            currentGame.status != GameStatus.FINISHED,
            "The game is already started or has ended"
        );

        currentGame.status = GameStatus.FINISHED;
        currentGame.winner = winner;
        emit GameEnded(lobbyID, gameID, block.timestamp, winner);
    }

    function payWinner(uint lobbyID, uint gameID) public {
        Game storage currentGame = game[lobbyID];
        require(currentGame.gameID != 0, "The game lobby does not exist");
        require(currentGame.gameID == gameID, "Invalid game Id");
        require(
            currentGame.status == GameStatus.FINISHED,
            "The game is has not finished yet"
        );
        require(
            currentGame.isPayoutDone == false,
            "Payment for this round was done earlier."
        );
        require(
            currentGame.hasConflict == false,
            "Cannot make payout because there are conflicting winners"
        );

        uint totalAmount = currentGame.totalAmount;
        currentGame.totalAmount = 0;
        (bool sent, ) = payable(currentGame.winner).call{value: totalAmount}(
            ""
        );
        require(sent, "Transaction unsuccesful");
    }
}
