package tutorial;

import java.util.Random;

public class TicTacToeGame {

    private final PLAYER[][] boardOccupancy;

    private PLAYER currentPlayer;

    private enum PLAYER {
        CROSS('x'), CIRCLE('o'), NONE('-');

        private char symbol;

        private PLAYER(char symbol) {
            this.symbol = symbol;
        }

        @Override
        public String toString() {
            return this.symbol + "";
        }
    }

    private static PLAYER[][] createInitialOccupancy() {
        PLAYER[][] result = new PLAYER[3][3];
        for (int i = 0; i < result.length; i++) {
            for (int j = 0; j < result[0].length; j++) {
                result[i][j] = PLAYER.NONE;
            }
        }
        return result;
    }

    /**
     * Creates a new game of TicTacToe. The first player is random.
     */
    public TicTacToeGame() {
        this.boardOccupancy = createInitialOccupancy();
        this.currentPlayer = new Random().nextBoolean() ? PLAYER.CIRCLE : PLAYER.CROSS;
    }

    /**
     * Prints the current board in text format.
     */
    public void printBoard() {
        System.out.println("Board:");
        for (int i = 0; i < this.boardOccupancy.length; i++) {
            for (int j = 0; j < this.boardOccupancy[0].length; j++) {
                System.out.print(boardOccupancy[i][j]);
            }
            System.out.println();
        }
    }

    /**
     * Plays a move as the current player, then switches to the other player. Does
     * nothing if the action is invalid (out of bounds or occupied cell).
     *
     * @param x The x coordinate.
     * @param y The y coordinate.
     */
    public void play(int x, int y) {
        if (x >= 0 && x <= 2 && y >= 0 && y <= 2 && boardOccupancy[x][y] == PLAYER.NONE) {
            this.boardOccupancy[x][y] = this.currentPlayer;
            this.currentPlayer = this.currentPlayer == PLAYER.CROSS ? PLAYER.CIRCLE : PLAYER.CROSS;
        }
    }
}
