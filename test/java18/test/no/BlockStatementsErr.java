public class BlockStatementsErr {
	public static void main(String[] args) {
		switch (a) {
			case 1:
				System.out.println("Ok\n");
				break;
			default:
				/* Nothing */
		}
	}
}