module d.gc.rbtree;

struct Node(N) {
private:
	Link!N[2] childs;
	
	@property
	ref Link!N left() {
		return childs[0];
	}
	
	@property
	ref Link!N right() {
		return childs[1];
	}
}

// TODO: when supported add default to use opCmp for compare.
struct RBTree(N, alias compare) {
private:
	N* root;
	
public:
	N* find(N* test) {
		auto n = root;
		
		while(n !is null) {
			auto cmp = compare(test, n);
			// We have a perfect match.
			if (cmp == 0) {
				return n;
			}
			
			n = n.node.childs[cmp > 0].node;
		}
		
		return null;
	}
	
	/**
	 * Find the smallest item that is larger than the test.
	 */
	N* bestfit(N* test) {
		auto n = root;
		
		N* bf = null;
		while(n !is null) {
			auto cmp = compare(test, n);
			// We have a perfect match.
			if (cmp == 0) {
				return n;
			}
			
			if (cmp < 0) {
				bf = n;
			}
			
			n = n.node.childs[cmp > 0].node;
		}
		
		return bf;
	}
	
	void insert(N* n) {
		// rbtree's depth is ln(n) which is at most 8 * size_t.sizeof.
		// Each tree node that N.sizeof size, so we can remove ln(N.sizeof).
		// But a branch can be at most 2* longer than the shortest one.
		import d.gc.util;
		Path!N[16 * size_t.sizeof - lg2floor(N.sizeof)] path = void;
		auto stackp = &path[0]; // TODO: use .ptr when available.
		
		// Let's make sure this is a child node.
		n.node.left = Link!N(null, Color.Black);
		n.node.right = Link!N(null, Color.Black);
		
		// Root is always black.
		auto link = Link!N(root, Color.Black);
		while (!link.isLeaf()) {
			auto diff = compare(n, link.node);
			assert(diff != 0);
			
			auto cmp = diff > 0;
			*stackp = Path!N(link, cmp);
			
			stackp++;
			link = link.childs[cmp];
		}
		
		// The tree only has a root.
		if (stackp is &path[0]) {
			root = n;
			return;
		}
		
		// Inserted node is always red.
		*stackp = Path!N(Link!N(n, Color.Red), false);
		assert(stackp.isRed());
		
		// Now we found an insertion point, let's fix the tree.
		for (stackp--; stackp !is (&path[0] - 1); stackp--) {
			link = stackp.link;
			auto cmp = stackp.cmp;
			
			auto child = link.childs[cmp] = stackp[1].link;
			if (child.isBlack()) {
				break;
			}
			
			if (link.isRed()) {
				continue;
			}
			
			auto sibling = link.childs[!cmp];
			if (sibling.isRed()) {
				assert(link.isBlack());
				assert(link.left.isRed() && link.right.isRed());
				
				/**
				 *     B          Br
				 *    / \   =>   / \
				 *   R   R      Rb  Rb
				 */
				link.left = link.left.getAs(Color.Black);
				link.right = link.right.getAs(Color.Black);
				*stackp = stackp.getWithLink(link.getAs(Color.Red));
				continue;
			}
			
			auto line = child.childs[cmp];
			if (line.isBlack()) {
				if (child.childs[!cmp].isBlack()) {
					// Our red child has 2 black child, we are good.
					break;
				}
				
				/**
				 * We transform The zigzag case into the line case.
				 *
				 *                 B
				 *     B          / \
				 *    / \        B   R
				 *   B   R   =>       \
				 *      / \            R
				 *     R   B            \
				 *                       B
				 */
				assert(child.childs[!cmp].isRed());
				child = child.rotate(cmp);
			}
			
			/**
			 *     B            Rb
			 *    / \          / \
			 *   B   R   =>   Br  R
			 *      / \      / \
			 *     B   R    B   B
			 */
			link.childs[cmp] = child.getAs(Color.Black);
			link = link.getAs(Color.Red);
			*stackp = stackp.getWithLink(link.rotate(!cmp));
		}
		
		root = path[0].node;
	}
	
	void remove(N* n) {
		// rbtree's depth is ln(n) which is at most 8 * size_t.sizeof.
		// Each tree node that N.sizeof size, so we can remove ln(N.sizeof).
		// But a branch can be at most 2* longer than the shortest one.
		import d.gc.util;
		Path!N[16 * size_t.sizeof - lg2floor(N.sizeof)] path = void;
		auto stackp = &path[0]; // TODO: use .ptr when available.
		
		// Root is always black.
		auto link = Link!N(root, Color.Black);
		while (true) {
			auto diff = compare(n, link.node);
			
			// We found our node !
			if (diff == 0) {
				break;
			}
			
			auto cmp = diff > 0;
			*stackp = Path!N(link, cmp);
			
			stackp++;
			link = link.childs[cmp];
			
			assert(!link.isLeaf(), "Element not found in rbtree");
		}
		
		// Now we look for a succesor.
		*stackp = Path!N(link, true);
		auto removep = stackp;
		auto removed = link;
		
		assert(removed.node is n);
		
		/**
		 * We find a replacing node by going one to the right
		 * and then as far as possible to the left. That way
		 * we get the next node in the tree and its ordering
		 * will be valid.
		 */
		link = removed.right;
		while(!link.isLeaf()) {
			stackp++;
			*stackp = Path!N(link, false);
			link = link.left;
		}
		
		link = stackp.link;
		
		if (stackp is removep) {
			// The node we remove has no successor.
			*stackp = stackp.getWithLink(link.left);
		} else {
			/**
			 * Swap node to be deleted with its successor
			 * but not the color, so we keep tree color
			 * constraint in place.
			 */
			auto rcolor = removed.color;
			
			removed = removed.getAs(link.color);
			*stackp = stackp.getWithLink(link.right);
			
			link = link.getAs(rcolor);
			link.left = removed.left;
			
			/**
			 * If the successor is the right child of the
			 * node we want to delete, this is incorrect.
			 * However, it doesn't matter, as it is going
			 * to be fixed during pruning.
			 */
			link.right = removed.right;
			
			// NB: We don't clean the node to be removed.
			// We simply splice it out.
			*removep = removep.getWithLink(link);
		}
		
		// If we are not at the root, fix the parent.
		if (removep !is &path[0]) {
			removep[-1].childs[removep[-1].cmp] = removep.link;
		}
		
		// Removing red node require no fixup.
		if (removed.isRed()) {
			stackp[-1].childs[stackp[-1].cmp] = Link!N(null, Color.Black);
			
			// Update root and exit
			root = path[0].node;
			return;
		}
		
		for (stackp--; stackp !is (&path[0] - 1); stackp--) {
			link = stackp.link;
			auto cmp = stackp.cmp;
			
			auto child = stackp[1].link;
			if (child.isRed()) {
				// If the double black is on a red node, recolor.
				link.childs[cmp] = child.getAs(Color.Black);
				break;
			}
			
			link.childs[cmp] = child;
			
			/**
			 * b = changed to black
			 * r = changed to red
			 * // = double black path
			 *
			 * We rotate and recolor to find ourselves in a case
			 * where sibling is black one level below. Because the
			 * new root will be red, zigzag case will bubble up
			 * with a red node, which is going to terminate.
			 *
			 *            Rb
			 *   B         \
			 *  / \\   =>   Br  <- new link
			 * R    B        \\
			 *                 B
			 */
			auto sibling = link.childs[!cmp];
			if (sibling.isRed()) {
				assert(link.isBlack());
				
				link = link.getAs(Color.Red);
				auto parent = link.rotate(cmp);
				*stackp = stackp.getWithLink(parent.getAs(Color.Black));
				
				// As we are going down one level, make sure we fix the parent.
				if (stackp !is &path[0]) {
					stackp[-1].childs[stackp[-1].cmp] = stackp.link;
				}
				
				stackp++;
				
				// Fake landing one level below.
				// NB: We don't need to fake cmp.
				*stackp = stackp.getWithLink(link);
				sibling = link.childs[!cmp];
			}
			
			auto line = sibling.childs[!cmp];
			if (line.isRed()) {
				goto Line;
			}
			
			if (sibling.childs[cmp].isBlack()) {
				/**
				 * b = changed to black
				 * r = changed to red
				 * // = double black path
				 *
				 * We recolor the sibling to push the double
				 * black one level up.
				 *
				 *     X           (X)
				 *    / \\         / \
				 *   B    B  =>   Br  B
				 *  / \          / \
				 * B   B        B   B
				 */
				link.childs[!cmp] = sibling.getAs(Color.Red);
				continue;
			}
			
			/**
			 * b = changed to black
			 * r = changed to red
			 * // = double black path
			 *
			 * We rotate the zigzag to be in the line case.
			 *
			 *                   X
			 *     X            / \\
			 *    / \\         Rb   B
			 *   B    B  =>   /
			 *  / \          Br
			 * B   R        /
			 *             B
			 */
			line = sibling.getAs(Color.Red);
			sibling = line.rotate(!cmp);
			sibling = sibling.getAs(Color.Black);
			link.childs[!cmp] = sibling;
			
			Line:
			/**
			 * b = changed to black
			 * x = changed to x's original color
			 * // = double black path
			 *
			 *     X           Bx
			 *    / \\        / \
			 *   B    B  =>  Rb  Xb
			 *  / \             / \
			 * R   Y           Y   B
			 */
			auto l = link.getAs(Color.Black);
			l = l.rotate(cmp);
			l.childs[!cmp] = line.getAs(Color.Black);
			
			// If we are the root, we are done.
			if (stackp is &path[0]) {
				root = l.node;
				return;
			}
			
			stackp[-1].childs[stackp[-1].cmp] = l.getAs(link.color);
			break;
		}
		
		// Update root and exit
		root = path[0].node;
	}
	
	void dump() {
		rb_print_tree(root);
	}
}

private:
//+
void rb_print_tree(N)(N* root) {
	Debug!N.print_tree(Link!N(root, Color.Black), 0);
}
// +/

private:

struct Link(N) {
	// This is effectively a tagged pointer, don't use as this.
	N* _child;
	
	this(N* n, Color c) {
		assert(c == Color.Black || n !is null);
		_child = cast(N*) ((cast(size_t) n) | c);
	}
	
	auto getAs(Color c) const {
		assert(c == Color.Black || node !is null);
		return Link(node, c);
	}
	
	@property
	N* node() {
		return cast(N*) ((cast(size_t) _child) & ~0x01);
	}
	
	@property
	ref Link left() {
		return node.node.left;
	}
	
	@property
	ref Link right() {
		return node.node.right;
	}
	
	@property
	ref Link[2] childs() {
		return node.node.childs;
	}
	
	@property
	Color color() const {
		return cast(Color) ((cast(size_t) _child) & 0x01);
	}
	
	bool isRed() const {
		return color == Color.Red;
	}
	
	bool isBlack() const {
		return color == Color.Black;
	}
	
	bool isLeaf() const {
		return _child is null;
	}
	
	// Rotate the tree and return the new root.
	// The tree turn clockwize if cmp is true,
	// counterclockwize if it is false.
	auto rotate(bool cmp) {
		auto x = childs[!cmp];
		childs[!cmp] = x.childs[cmp];
		x.childs[cmp] = this;
		return x;
	}
	
	// Rotate the tree and return the new root.
	auto rotateLeft() {
		auto r = right;
		right = r.left;
		r.left = this;
		return r;
	}
	
	// Rotate the tree and return the new root.
	auto rotateRight() {
		auto l = left;
		left = l.right;
		l.right = this;
		return l;
	}
}

enum Color : bool {
	Black = false,
	Red = true,
}

struct Path(N) {
	// This is effectively a tagged pointer, don't use as this.
	N* _child;
	
	this(Link!N l, bool c) {
		_child = cast(N*) ((cast(size_t) l._child) | (c << 1));
	}
	
	auto getWithLink(Link!N l) {
		return Path(l, cmp);
	}
	
	auto getWithCmp(bool c) {
		return Path(link, c);
	}
	
	@property
	Link!N link() {
		return Link!N(node, color);
	}
	
	@property
	bool cmp() const {
		return !!((cast(size_t) _child) & 0x02);
	}
	
	@property
	N* node() {
		return cast(N*) ((cast(size_t) _child) & ~0x03);
	}
	
	@property
	ref Link!N left() {
		return node.node.left;
	}
	
	@property
	ref Link!N right() {
		return node.node.right;
	}
	
	@property
	ref Link!N[2] childs() {
		return node.node.childs;
	}
	
	@property
	Color color() const {
		return cast(Color) ((cast(size_t) _child) & 0x01);
	}
	
	bool isRed() const {
		return color == Color.Red;
	}
	
	bool isBlack() const {
		return color == Color.Black;
	}
}

//+
template Debug(N) {
void print_tree(Link!N root, uint depth) {
	foreach (i; 0 .. depth) {
		printf("\t".ptr);
	}
	
	if (root.isBlack()) {
		printf("B %p\n".ptr, root.node);
	} else {
		assert(root.isRed());
		printf("R %p\n".ptr, root.node);
	}
	
	if (!root.isLeaf()) {
		print_tree(root.right, depth + 1);
		print_tree(root.left, depth + 1);
	}
}
}
// +/